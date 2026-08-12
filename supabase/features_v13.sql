-- Features v13: team-building matching ("Tinder for teammates").
-- Users like/pass developer cards; a mutual like opens a match and chat.
-- Apply in Supabase SQL editor after features_v12.

create table if not exists public.match_swipes (
  id uuid primary key default gen_random_uuid(),
  swiper_id uuid not null references public.profiles (id) on delete cascade,
  target_id uuid not null references public.profiles (id) on delete cascade,
  liked boolean not null,
  created_at timestamptz not null default now(),
  constraint match_swipes_not_self check (swiper_id <> target_id),
  constraint match_swipes_unique unique (swiper_id, target_id)
);

alter table public.match_swipes enable row level security;

drop policy if exists "Users can view own swipes" on public.match_swipes;
create policy "Users can view own swipes"
  on public.match_swipes for select to authenticated
  using (auth.uid() = swiper_id or auth.uid() = target_id);

drop policy if exists "Users can insert own swipes" on public.match_swipes;
create policy "Users can insert own swipes"
  on public.match_swipes for insert to authenticated
  with check (auth.uid() = swiper_id);

drop policy if exists "Users can delete own swipes" on public.match_swipes;
create policy "Users can delete own swipes"
  on public.match_swipes for delete to authenticated
  using (auth.uid() = swiper_id);

create index if not exists match_swipes_swiper_idx
  on public.match_swipes (swiper_id);

create index if not exists match_swipes_target_liked_idx
  on public.match_swipes (target_id, liked)
  where liked;

-- Feed of people to swipe: complementary search status + shared skills first.
create or replace function public.get_match_feed(p_limit int default 40)
returns table (
  id uuid,
  login text,
  status text,
  avatar_emoji text,
  avatar_url text,
  is_bot boolean,
  dev_status text,
  skills text[],
  experience_level text,
  github_url text,
  portfolio_url text,
  city text,
  shared_skills int
)
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  my_status text;
  my_skills text[];
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  select p.dev_status, coalesce(p.skills, '{}')
    into my_status, my_skills
  from public.profiles p
  where p.id = uid;

  return query
  select
    p.id,
    p.login,
    p.status,
    p.avatar_emoji,
    p.avatar_url,
    coalesce(p.is_bot, false) as is_bot,
    p.dev_status,
    coalesce(p.skills, '{}'::text[]) as skills,
    p.experience_level,
    p.github_url,
    p.portfolio_url,
    p.city,
    (
      select count(*)::int
      from unnest(coalesce(p.skills, '{}'::text[])) s
      where lower(s) in (select lower(x) from unnest(my_skills) x)
    ) as shared_skills
  from public.profiles p
  where p.id <> uid
    and coalesce(p.is_bot, false) = false
    and (
      p.dev_status <> 'none'
      or cardinality(coalesce(p.skills, '{}'::text[])) > 0
    )
    and not exists (
      select 1 from public.match_swipes s
      where s.swiper_id = uid and s.target_id = p.id
    )
    and (
      -- complementary goals first; open_to_offers / none viewers see everyone
      my_status is null
      or my_status in ('none', 'open_to_offers')
      or p.dev_status = 'open_to_offers'
      or (my_status = 'looking_for_team' and p.dev_status in ('looking_for_members', 'open_to_offers'))
      or (my_status = 'looking_for_members' and p.dev_status in ('looking_for_team', 'open_to_offers'))
      or p.dev_status = my_status
      or p.dev_status = 'none'
    )
  order by
    shared_skills desc,
    case
      when my_status = 'looking_for_team' and p.dev_status = 'looking_for_members' then 0
      when my_status = 'looking_for_members' and p.dev_status = 'looking_for_team' then 0
      when p.dev_status = 'open_to_offers' then 1
      else 2
    end,
    p.updated_at desc nulls last,
    p.created_at desc
  limit greatest(1, least(coalesce(p_limit, 40), 100));
end;
$$;

grant execute on function public.get_match_feed(int) to authenticated;

-- Record a like/pass; returns whether it became a mutual match.
create or replace function public.swipe_match(p_target_id uuid, p_liked boolean)
returns table (is_match boolean)
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  mutual boolean := false;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_target_id is null or p_target_id = uid then
    raise exception 'Invalid target';
  end if;
  if not exists (select 1 from public.profiles where id = p_target_id) then
    raise exception 'User not found';
  end if;

  insert into public.match_swipes (swiper_id, target_id, liked)
  values (uid, p_target_id, p_liked)
  on conflict (swiper_id, target_id) do update
    set liked = excluded.liked,
        created_at = now();

  if p_liked then
    select exists (
      select 1
      from public.match_swipes s
      where s.swiper_id = p_target_id
        and s.target_id = uid
        and s.liked = true
    ) into mutual;
  end if;

  return query select mutual;
end;
$$;

grant execute on function public.swipe_match(uuid, boolean) to authenticated;

-- Mutual likes for the current user.
create or replace function public.get_my_matches()
returns table (
  id uuid,
  login text,
  status text,
  avatar_emoji text,
  avatar_url text,
  is_bot boolean,
  dev_status text,
  skills text[],
  experience_level text,
  github_url text,
  portfolio_url text,
  city text,
  matched_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  return query
  select
    p.id,
    p.login,
    p.status,
    p.avatar_emoji,
    p.avatar_url,
    coalesce(p.is_bot, false) as is_bot,
    p.dev_status,
    coalesce(p.skills, '{}'::text[]) as skills,
    p.experience_level,
    p.github_url,
    p.portfolio_url,
    p.city,
    greatest(s1.created_at, s2.created_at) as matched_at
  from public.match_swipes s1
  join public.match_swipes s2
    on s2.swiper_id = s1.target_id
   and s2.target_id = s1.swiper_id
   and s2.liked = true
  join public.profiles p on p.id = s1.target_id
  where s1.swiper_id = uid
    and s1.liked = true
  order by matched_at desc;
end;
$$;

grant execute on function public.get_my_matches() to authenticated;
