-- Features v26: Murkot Plus cosmetics + profile analytics
-- Apply after features_v25.sql

alter table public.profiles
  add column if not exists avatar_frame text not null default 'none',
  add column if not exists nick_color text,
  add column if not exists is_plus boolean not null default false,
  add column if not exists plus_until timestamptz;

alter table public.profiles drop constraint if exists profiles_avatar_frame_check;
alter table public.profiles
  add constraint profiles_avatar_frame_check
  check (avatar_frame in ('none','stars','sparkle','wave','dots','citrus','drops'));

-- Public directory must expose Plus cosmetics.
create or replace view public.public_profiles
with (security_invoker = false) as
select
  id,
  login,
  status,
  avatar_url,
  avatar_emoji,
  profile_wallpaper_id,
  custom_wallpaper_url,
  birthday,
  created_at,
  updated_at,
  coalesce(dev_status, 'none') as dev_status,
  coalesce(skills, '{}'::text[]) as skills,
  experience_level,
  github_url,
  portfolio_url,
  city,
  coalesce(is_bot, false) as is_bot,
  last_seen_at,
  coalesce(avatar_frame, 'none') as avatar_frame,
  nick_color,
  coalesce(is_plus, false) as is_plus,
  plus_until
from public.profiles;

grant select on public.public_profiles to authenticated, anon;

grant select (
  avatar_frame, nick_color, is_plus, plus_until
) on table public.profiles to authenticated, anon;

grant update (
  avatar_frame, nick_color, is_plus, plus_until
) on table public.profiles to authenticated;

-- Who viewed my profile ------------------------------------------------
create table if not exists public.profile_views (
  id uuid primary key default gen_random_uuid(),
  viewer_id uuid not null references public.profiles(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (viewer_id, profile_id)
);

create index if not exists profile_views_profile_idx
  on public.profile_views (profile_id, created_at desc);

alter table public.profile_views enable row level security;

drop policy if exists "Users insert own profile views" on public.profile_views;
create policy "Users insert own profile views"
  on public.profile_views for insert to authenticated
  with check (viewer_id = auth.uid() and viewer_id <> profile_id);

drop policy if exists "Plus owners see views" on public.profile_views;
create policy "Plus owners see views"
  on public.profile_views for select to authenticated
  using (
    profile_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and coalesce(p.is_plus, false)
    )
  );

create or replace function public.record_profile_view(p_login text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_target uuid;
begin
  if v_uid is null then return; end if;
  select id into v_target from public.profiles
  where lower(login) = lower(trim(p_login)) limit 1;
  if v_target is null or v_target = v_uid then return; end if;
  insert into public.profile_views (viewer_id, profile_id)
  values (v_uid, v_target)
  on conflict (viewer_id, profile_id)
  do update set created_at = now();
end;
$$;
grant execute on function public.record_profile_view(text) to authenticated;

create or replace function public.list_my_profile_views(p_limit int default 40)
returns table (
  viewer_id uuid,
  login text,
  avatar_emoji text,
  avatar_url text,
  avatar_frame text,
  nick_color text,
  viewed_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and coalesce(p.is_plus, false)
  ) then
    raise exception 'Plus required';
  end if;

  return query
  select
    v.viewer_id,
    p.login,
    p.avatar_emoji,
    p.avatar_url,
    coalesce(p.avatar_frame, 'none'),
    p.nick_color,
    v.created_at
  from public.profile_views v
  join public.profiles p on p.id = v.viewer_id
  where v.profile_id = auth.uid()
  order by v.created_at desc
  limit greatest(1, least(coalesce(p_limit, 40), 100));
end;
$$;
grant execute on function public.list_my_profile_views(int) to authenticated;

-- Contact saves (respond / airdrop / open chat from profile) ------------
create table if not exists public.contact_saves (
  id uuid primary key default gen_random_uuid(),
  saver_id uuid not null references public.profiles(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  source text not null default 'chat',
  created_at timestamptz not null default now(),
  unique (saver_id, profile_id, source)
);

create index if not exists contact_saves_profile_idx
  on public.contact_saves (profile_id, created_at desc);

alter table public.contact_saves enable row level security;

drop policy if exists "Users insert own contact saves" on public.contact_saves;
create policy "Users insert own contact saves"
  on public.contact_saves for insert to authenticated
  with check (saver_id = auth.uid() and saver_id <> profile_id);

drop policy if exists "Plus owners see contact saves" on public.contact_saves;
create policy "Plus owners see contact saves"
  on public.contact_saves for select to authenticated
  using (
    profile_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and coalesce(p.is_plus, false)
    )
  );

create or replace function public.record_contact_save(p_login text, p_source text default 'chat')
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_target uuid;
  v_source text := coalesce(nullif(trim(p_source), ''), 'chat');
begin
  if v_uid is null then return; end if;
  select id into v_target from public.profiles
  where lower(login) = lower(trim(p_login)) limit 1;
  if v_target is null or v_target = v_uid then return; end if;
  insert into public.contact_saves (saver_id, profile_id, source)
  values (v_uid, v_target, v_source)
  on conflict (saver_id, profile_id, source)
  do update set created_at = now();
end;
$$;
grant execute on function public.record_contact_save(text, text) to authenticated;

create or replace function public.list_my_contact_saves(p_limit int default 40)
returns table (
  saver_id uuid,
  login text,
  avatar_emoji text,
  avatar_url text,
  avatar_frame text,
  nick_color text,
  source text,
  saved_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and coalesce(p.is_plus, false)
  ) then
    raise exception 'Plus required';
  end if;

  return query
  select
    s.saver_id,
    p.login,
    p.avatar_emoji,
    p.avatar_url,
    coalesce(p.avatar_frame, 'none'),
    p.nick_color,
    s.source,
    s.created_at
  from public.contact_saves s
  join public.profiles p on p.id = s.saver_id
  where s.profile_id = auth.uid()
  order by s.created_at desc
  limit greatest(1, least(coalesce(p_limit, 40), 100));
end;
$$;
grant execute on function public.list_my_contact_saves(int) to authenticated;

-- Free daily boosts (top) -----------------------------------------------
create table if not exists public.listing_boost_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  listing_id uuid references public.listings(id) on delete set null,
  kind text not null default 'top',
  created_at timestamptz not null default now()
);

create index if not exists listing_boost_log_user_day_idx
  on public.listing_boost_log (user_id, created_at desc);

alter table public.listing_boost_log enable row level security;

drop policy if exists "Users manage own boost log" on public.listing_boost_log;
create policy "Users manage own boost log"
  on public.listing_boost_log for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create or replace function public.consume_free_top_boost(p_listing_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_plus boolean := false;
  v_used int := 0;
  v_limit int := 1;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  select coalesce(is_plus, false) into v_plus from public.profiles where id = v_uid;
  v_limit := case when v_plus then 5 else 1 end;
  select count(*)::int into v_used
  from public.listing_boost_log
  where user_id = v_uid
    and kind = 'top'
    and created_at > date_trunc('day', now());
  if v_used >= v_limit then
    return false;
  end if;
  insert into public.listing_boost_log (user_id, listing_id, kind)
  values (v_uid, p_listing_id, 'top');
  update public.listings
    set created_at = now(), updated_at = now()
  where id = p_listing_id and author_id = v_uid;
  return true;
end;
$$;
grant execute on function public.consume_free_top_boost(uuid) to authenticated;

create or replace function public.free_top_boosts_left()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_plus boolean := false;
  v_used int := 0;
  v_limit int := 1;
begin
  if v_uid is null then return 0; end if;
  select coalesce(is_plus, false) into v_plus from public.profiles where id = v_uid;
  v_limit := case when v_plus then 5 else 1 end;
  select count(*)::int into v_used
  from public.listing_boost_log
  where user_id = v_uid
    and kind = 'top'
    and created_at > date_trunc('day', now());
  return greatest(0, v_limit - v_used);
end;
$$;
grant execute on function public.free_top_boosts_left() to authenticated;

-- Expose Plus cosmetics in people search -------------------------
drop function if exists public.search_people(text, text, text, text, int, int);

create or replace function public.search_people(
  p_query text default null,
  p_skill text default null,
  p_city text default null,
  p_dev_status text default null,
  p_limit int default 40,
  p_offset int default 0
)
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
  shared_skills int,
  created_at timestamptz,
  avatar_frame text,
  nick_color text,
  is_plus boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_my_skills text[] := '{}'::text[];
  v_q text := nullif(trim(coalesce(p_query, '')), '');
  v_skill text := nullif(trim(coalesce(p_skill, '')), '');
  v_city text := nullif(trim(coalesce(p_city, '')), '');
  v_dstatus text := nullif(trim(coalesce(p_dev_status, '')), '');
  v_lim int := greatest(1, least(coalesce(p_limit, 40), 100));
  v_off int := greatest(0, coalesce(p_offset, 0));
begin
  if v_uid is not null then
    select coalesce(p.skills, '{}'::text[])
      into v_my_skills
    from public.profiles p
    where p.id = v_uid;
  end if;

  return query
  select
    p.id,
    p.login,
    p.status,
    p.avatar_emoji,
    p.avatar_url,
    coalesce(p.is_bot, false),
    coalesce(p.dev_status, 'none'),
    coalesce(p.skills, '{}'::text[]),
    p.experience_level,
    p.github_url,
    p.portfolio_url,
    p.city,
    (
      select count(*)::int
      from unnest(coalesce(p.skills, '{}'::text[])) s
      where lower(s) in (select lower(x) from unnest(v_my_skills) x)
    ),
    p.created_at,
    coalesce(p.avatar_frame, 'none'),
    p.nick_color,
    coalesce(p.is_plus, false)
  from public.profiles p
  where (v_uid is null or p.id <> v_uid)
    and coalesce(p.is_bot, false) = false
    and (
      coalesce(p.dev_status, 'none') <> 'none'
      or cardinality(coalesce(p.skills, '{}'::text[])) > 0
      or nullif(trim(coalesce(p.city, '')), '') is not null
    )
    and (v_dstatus is null or coalesce(p.dev_status, 'none') = v_dstatus)
    and (
      v_skill is null
      or exists (
        select 1
        from unnest(coalesce(p.skills, '{}'::text[])) s
        where lower(s) = lower(v_skill)
      )
    )
    and (
      v_city is null
      or lower(trim(coalesce(p.city, ''))) = lower(v_city)
    )
    and (
      v_q is null
      or p.login ilike '%' || v_q || '%'
      or coalesce(p.status, '') ilike '%' || v_q || '%'
      or coalesce(p.city, '') ilike '%' || v_q || '%'
      or exists (
        select 1
        from unnest(coalesce(p.skills, '{}'::text[])) s
        where s ilike '%' || v_q || '%'
      )
    )
    and (
      v_uid is null or not exists (
        select 1 from public.blocked_users b
        where b.blocker_id = v_uid
          and lower(b.blocked_login) = lower(p.login)
      )
    )
    and (
      v_uid is null or not exists (
        select 1 from public.blocked_users b
        join public.profiles me on me.id = v_uid
        where b.blocker_id = p.id
          and lower(b.blocked_login) = lower(me.login)
      )
    )
  order by
    13 desc,
    case
      when v_q is not null and lower(p.login) = lower(v_q) then 0
      when v_q is not null and lower(p.login) like lower(v_q) || '%' then 1
      else 2
    end,
    p.login
  limit v_lim
  offset v_off;
end;
$$;

grant execute on function public.search_people(text, text, text, text, int, int)
  to anon, authenticated;
