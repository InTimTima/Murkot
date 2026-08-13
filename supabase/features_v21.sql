-- Features v21: admin panel for logins tima and hex.
-- Apply after features_v20.sql
-- Stats, user search, account disable — all gated by is_app_admin().

-- ─── Disabled flag ──────────────────────────────────────────
alter table public.profiles
  add column if not exists is_disabled boolean not null default false;

-- ─── Admin check (login allowlist) ──────────────────────────
create or replace function public.is_app_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and lower(login) in ('tima', 'hex')
  );
$$;

grant execute on function public.is_app_admin() to authenticated;

-- Admins are always moderators (reports queue).
create or replace function public.is_app_moderator()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    exists (
      select 1 from public.app_moderators where user_id = auth.uid()
    )
    or exists (
      select 1
      from public.profiles
      where id = auth.uid()
        and lower(login) in ('tima', 'hex')
    );
$$;

grant execute on function public.is_app_moderator() to authenticated;

insert into public.app_moderators (user_id)
select p.id
from public.profiles p
where lower(p.login) in ('tima', 'hex')
on conflict do nothing;

-- ─── Overview stats ─────────────────────────────────────────
create or replace function public.admin_overview()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_out jsonb;
  v_n bigint;
begin
  if not public.is_app_admin() then
    raise exception 'Not an admin';
  end if;

  v_out := jsonb_build_object(
    'users_total', (select count(*)::int from public.profiles),
    'users_online', (
      select count(*)::int
      from public.profiles
      where last_seen_at is not null
        and last_seen_at > now() - interval '3 minutes'
        and not is_disabled
    ),
    'users_today', (
      select count(*)::int
      from public.profiles
      where created_at >= date_trunc('day', now())
    ),
    'users_week', (
      select count(*)::int
      from public.profiles
      where created_at >= now() - interval '7 days'
    ),
    'users_disabled', (
      select count(*)::int from public.profiles where is_disabled
    ),
    'conversations_total', (
      select count(*)::int from public.conversations
    ),
    'conversations_direct', (
      select count(*)::int from public.conversations where type = 'direct'
    ),
    'conversations_group', (
      select count(*)::int from public.conversations where type = 'group'
    ),
    'conversations_channel', (
      select count(*)::int from public.conversations where type = 'channel'
    ),
    'messages_today', (
      select count(*)::int
      from public.messages
      where created_at >= date_trunc('day', now())
        and not is_deleted_for_all
    ),
    'messages_total', (select count(*)::int from public.messages)
  );

  if to_regclass('public.listings') is not null then
    execute 'select count(*) from public.listings' into v_n;
    v_out := v_out || jsonb_build_object('listings_total', v_n::int);
    execute 'select count(*) from public.listings where is_active' into v_n;
    v_out := v_out || jsonb_build_object('listings_active', v_n::int);
  else
    v_out := v_out || jsonb_build_object('listings_total', 0, 'listings_active', 0);
  end if;

  if to_regclass('public.projects') is not null then
    execute 'select count(*) from public.projects' into v_n;
    v_out := v_out || jsonb_build_object('projects_total', v_n::int);
  else
    v_out := v_out || jsonb_build_object('projects_total', 0);
  end if;

  if to_regclass('public.content_reports') is not null then
    execute
      $q$select count(*) from public.content_reports where status = 'open'$q$
      into v_n;
    v_out := v_out || jsonb_build_object('reports_open', v_n::int);
  else
    v_out := v_out || jsonb_build_object('reports_open', 0);
  end if;

  if to_regclass('public.match_swipes') is not null then
    execute
      $q$select count(*) from public.match_swipes
         where created_at >= date_trunc('day', now())$q$
      into v_n;
    v_out := v_out || jsonb_build_object('swipes_today', v_n::int);
  else
    v_out := v_out || jsonb_build_object('swipes_today', 0);
  end if;

  return v_out;
end;
$$;

grant execute on function public.admin_overview() to authenticated;

-- ─── User directory ─────────────────────────────────────────
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

-- ─── Disable / enable account ───────────────────────────────
create or replace function public.admin_set_user_disabled(
  p_user_id uuid,
  p_disabled boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_login text;
begin
  if not public.is_app_admin() then
    raise exception 'Not an admin';
  end if;

  if p_user_id = auth.uid() then
    raise exception 'Cannot disable your own account';
  end if;

  select login into v_login from public.profiles where id = p_user_id;
  if v_login is null then
    raise exception 'User not found';
  end if;
  if lower(v_login) in ('tima', 'hex') then
    raise exception 'Cannot disable an admin account';
  end if;

  update public.profiles
  set is_disabled = coalesce(p_disabled, false)
  where id = p_user_id;
end;
$$;

grant execute on function public.admin_set_user_disabled(uuid, boolean) to authenticated;

-- ─── Take down all of a user's board ads ────────────────────
create or replace function public.admin_deactivate_user_listings(
  p_user_id uuid
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_n int := 0;
begin
  if not public.is_app_admin() then
    raise exception 'Not an admin';
  end if;

  if to_regclass('public.listings') is null then
    return 0;
  end if;

  update public.listings
  set is_active = false, updated_at = now()
  where author_id = p_user_id and is_active;

  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

grant execute on function public.admin_deactivate_user_listings(uuid) to authenticated;
