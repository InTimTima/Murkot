-- Features v20: people directory search (skills / city / status).
-- Apply after features_v19.

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
  uid uuid := auth.uid();
  my_skills text[];
  q text := nullif(trim(coalesce(p_query, '')), '');
  skill text := nullif(trim(coalesce(p_skill, '')), '');
  city text := nullif(trim(coalesce(p_city, '')), '');
  dstatus text := nullif(trim(coalesce(p_dev_status, '')), '');
  lim int := greatest(1, least(coalesce(p_limit, 40), 100));
  off int := greatest(0, coalesce(p_offset, 0));
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  select coalesce(p.skills, '{}'::text[])
    into my_skills
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
    coalesce(p.dev_status, 'none') as dev_status,
    coalesce(p.skills, '{}'::text[]) as skills,
    p.experience_level,
    p.github_url,
    p.portfolio_url,
    p.city,
    (
      select count(*)::int
      from unnest(coalesce(p.skills, '{}'::text[])) s
      where lower(s) in (select lower(x) from unnest(my_skills) x)
    ) as shared_skills,
    p.created_at
  from public.profiles p
  where p.id <> uid
    and coalesce(p.is_bot, false) = false
    and (
      coalesce(p.dev_status, 'none') <> 'none'
      or cardinality(coalesce(p.skills, '{}'::text[])) > 0
      or nullif(trim(coalesce(p.city, '')), '') is not null
    )
    and (dstatus is null or coalesce(p.dev_status, 'none') = dstatus)
    and (
      skill is null
      or exists (
        select 1
        from unnest(coalesce(p.skills, '{}'::text[])) s
        where lower(s) = lower(skill)
      )
    )
    and (
      city is null
      or lower(trim(coalesce(p.city, ''))) = lower(city)
    )
    and (
      q is null
      or p.login ilike '%' || q || '%'
      or coalesce(p.status, '') ilike '%' || q || '%'
      or coalesce(p.city, '') ilike '%' || q || '%'
      or exists (
        select 1
        from unnest(coalesce(p.skills, '{}'::text[])) s
        where s ilike '%' || q || '%'
      )
    )
    and not exists (
      select 1 from public.blocked_users b
      where b.blocker_id = uid
        and lower(b.blocked_login) = lower(p.login)
    )
    and not exists (
      select 1 from public.blocked_users b
      join public.profiles me on me.id = uid
      where b.blocker_id = p.id
        and lower(b.blocked_login) = lower(me.login)
    )
  order by
    shared_skills desc,
    case
      when q is not null and lower(p.login) = lower(q) then 0
      when q is not null and lower(p.login) like lower(q) || '%' then 1
      else 2
    end,
    p.login
  limit lim
  offset off;
end;
$$;

grant execute on function public.search_people(text, text, text, text, int, int)
  to authenticated;
