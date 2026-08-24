-- Features v23: guest can actually SEE names, avatars, people, match, communities.
-- Apply after features_v22.sql
-- v22 granted listings/projects to anon, but embeds still hit profiles RLS
-- (`to authenticated` only), and people/match/community RPCs raise if auth.uid() is null.

-- ─── Profiles: public columns for guests ────────────────────
drop policy if exists "Anon can view public profile columns" on public.profiles;
create policy "Anon can view public profile columns"
  on public.profiles for select to anon
  using (true);

grant select on public.public_profiles to anon;
grant execute on function public.get_public_profile_by_login(text) to anon;

-- ─── People directory: allow anonymous browse ───────────────
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
  created_at timestamptz
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
    p.created_at
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

-- ─── Match feed: guests can browse cards (swipe still requires login) ──
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
  my_status text := 'none';
  my_skills text[] := '{}'::text[];
begin
  if uid is not null then
    select coalesce(p.dev_status, 'none'), coalesce(p.skills, '{}')
      into my_status, my_skills
    from public.profiles p
    where p.id = uid;
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
    (
      select count(*)::int
      from unnest(coalesce(p.skills, '{}'::text[])) s
      where lower(s) in (select lower(x) from unnest(my_skills) x)
    ) as shared_skills
  from public.profiles p
  where (uid is null or p.id <> uid)
    and coalesce(p.is_bot, false) = false
    and (
      p.dev_status <> 'none'
      or cardinality(coalesce(p.skills, '{}'::text[])) > 0
    )
    and (
      uid is null or not exists (
        select 1 from public.match_swipes s
        where s.swiper_id = uid and s.target_id = p.id
      )
    )
    and (
      uid is null
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

grant execute on function public.get_match_feed(int) to anon, authenticated;

-- ─── Community catalog: guests can list rooms ───────────────
create or replace function public.list_community_channels()
returns table (
  id uuid,
  type text,
  name text,
  description text,
  avatar_emoji text,
  avatar_url text,
  category text,
  member_count bigint,
  is_member boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  return query
  select
    c.id,
    c.type,
    c.name,
    c.description,
    c.avatar_emoji,
    c.avatar_url,
    c.category,
    (
      select count(*)::bigint
      from public.conversation_members m
      where m.conversation_id = c.id
    ) as member_count,
    (
      uid is not null and exists (
        select 1
        from public.conversation_members m
        where m.conversation_id = c.id and m.user_id = uid
      )
    ) as is_member
  from public.conversations c
  where c.is_featured = true
    and c.type in ('group', 'channel')
  order by
    case c.category
      when 'startup' then 0
      when 'career' then 1
      when 'dev' then 2
      when 'creative' then 3
      else 4
    end,
    c.name;
end;
$$;

grant execute on function public.list_community_channels() to anon, authenticated;
grant execute on function public.search_public_conversations(text, text) to anon, authenticated;

-- Fallback if the RPC is stale: guests can still read featured rooms.
grant select (
  id, type, name, description, avatar_emoji, avatar_url,
  category, is_featured, is_public
) on table public.conversations to anon;

drop policy if exists "Anon can view featured communities" on public.conversations;
create policy "Anon can view featured communities"
  on public.conversations for select to anon
  using (is_featured = true and coalesce(is_public, false) = true);
