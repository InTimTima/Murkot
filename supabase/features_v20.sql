-- Features v20: people directory search (skills / city / status).
-- Apply after features_v19.
-- Re-run this file if you already applied an earlier v20 draft
-- (fixes ambiguous OUT-column names: city / shared_skills).

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
  v_my_skills text[];
  v_q text := nullif(trim(coalesce(p_query, '')), '');
  v_skill text := nullif(trim(coalesce(p_skill, '')), '');
  v_city text := nullif(trim(coalesce(p_city, '')), '');
  v_dstatus text := nullif(trim(coalesce(p_dev_status, '')), '');
  v_lim int := greatest(1, least(coalesce(p_limit, 40), 100));
  v_off int := greatest(0, coalesce(p_offset, 0));
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select coalesce(p.skills, '{}'::text[])
    into v_my_skills
  from public.profiles p
  where p.id = v_uid;

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
  where p.id <> v_uid
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
    and not exists (
      select 1 from public.blocked_users b
      where b.blocker_id = v_uid
        and lower(b.blocked_login) = lower(p.login)
    )
    and not exists (
      select 1 from public.blocked_users b
      join public.profiles me on me.id = v_uid
      where b.blocker_id = p.id
        and lower(b.blocked_login) = lower(me.login)
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
  to authenticated;
