-- Features v24: admin avatars — expose avatar_url in admin_list_users
-- Apply after features_v21.sql. Mirrors _UserRow model so admin panel shows real avatars.
-- Postgres can't change RETURN type with CREATE OR REPLACE, so drop first.

drop function if exists public.admin_list_users(text, boolean, int, int);

create or replace function public.admin_list_users(
  p_query text default null,
  p_online_only boolean default false,
  p_limit int default 40,
  p_offset int default 0
)
returns table (
  id uuid,
  login text,
  avatar_emoji text,
  avatar_url text,
  city text,
  created_at timestamptz,
  last_seen_at timestamptz,
  is_disabled boolean,
  is_online boolean,
  listings_active int,
  listings_total int,
  is_admin boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_q text := nullif(trim(coalesce(p_query, '')), '');
  v_limit int := greatest(1, least(coalesce(p_limit, 40), 100));
  v_offset int := greatest(0, coalesce(p_offset, 0));
begin
  if not public.is_app_admin() then
    raise exception 'Not an admin';
  end if;

  return query
  select
    p.id,
    p.login,
    p.avatar_emoji,
    p.avatar_url,
    p.city,
    p.created_at,
    p.last_seen_at,
    p.is_disabled,
    (p.last_seen_at is not null
      and p.last_seen_at > now() - interval '3 minutes') as is_online,
    case
      when to_regclass('public.listings') is null then 0
      else (
        select count(*)::int
        from public.listings l
        where l.author_id = p.id and l.is_active
      )
    end as listings_active,
    case
      when to_regclass('public.listings') is null then 0
      else (
        select count(*)::int from public.listings l where l.author_id = p.id
      )
    end as listings_total,
    (lower(p.login) in ('tima', 'hex')) as is_admin
  from public.profiles p
  where
    (v_q is null or p.login ilike '%' || v_q || '%' or coalesce(p.city, '') ilike '%' || v_q || '%')
    and (
      not coalesce(p_online_only, false)
      or (
        p.last_seen_at is not null
        and p.last_seen_at > now() - interval '3 minutes'
        and not p.is_disabled
      )
    )
  order by
    (p.last_seen_at is not null
      and p.last_seen_at > now() - interval '3 minutes') desc,
    p.last_seen_at desc nulls last,
    p.created_at desc
  limit v_limit
  offset v_offset;
end;
$$;

grant execute on function public.admin_list_users(text, boolean, int, int) to authenticated;
