-- Features v18: moderation queue for content_reports
-- Apply after features_v17.sql

-- ─── Moderators allowlist ───────────────────────────────────
create table if not exists public.app_moderators (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.app_moderators enable row level security;

drop policy if exists "Mods can see moderators" on public.app_moderators;
create policy "Mods can see moderators"
  on public.app_moderators for select to authenticated
  using (
    exists (
      select 1 from public.app_moderators m where m.user_id = auth.uid()
    )
  );

create or replace function public.is_app_moderator()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.app_moderators where user_id = auth.uid()
  );
$$;

grant execute on function public.is_app_moderator() to authenticated;

-- First moderator bootstrap (only if none yet): earliest profile.
insert into public.app_moderators (user_id)
select p.id
from public.profiles p
where not exists (select 1 from public.app_moderators)
order by p.created_at asc nulls last
limit 1
on conflict do nothing;

-- ─── Report workflow columns ────────────────────────────────
alter table public.content_reports
  add column if not exists status text not null default 'open';

alter table public.content_reports
  drop constraint if exists content_reports_status_check;

alter table public.content_reports
  add constraint content_reports_status_check
  check (status in ('open', 'resolved', 'dismissed'));

alter table public.content_reports
  add column if not exists resolved_at timestamptz;

alter table public.content_reports
  add column if not exists resolved_by uuid references public.profiles (id) on delete set null;

alter table public.content_reports
  add column if not exists resolution_note text not null default '';

create index if not exists content_reports_status_created_idx
  on public.content_reports (status, created_at desc);

-- ─── Moderator RPCs ─────────────────────────────────────────
create or replace function public.list_content_reports(
  p_status text default 'open',
  p_limit int default 50
)
returns table (
  id uuid,
  reporter_id uuid,
  reporter_login text,
  target_type text,
  target_id text,
  reason text,
  status text,
  created_at timestamptz,
  resolved_at timestamptz,
  resolution_note text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_app_moderator() then
    raise exception 'Not a moderator';
  end if;

  if p_status is not null and p_status not in ('open', 'resolved', 'dismissed', 'all') then
    raise exception 'Invalid status';
  end if;

  return query
  select
    r.id,
    r.reporter_id,
    coalesce(p.login, '?') as reporter_login,
    r.target_type,
    r.target_id,
    r.reason,
    r.status,
    r.created_at,
    r.resolved_at,
    r.resolution_note
  from public.content_reports r
  left join public.profiles p on p.id = r.reporter_id
  where (p_status is null or p_status = 'all' or r.status = p_status)
  order by r.created_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 200));
end;
$$;

grant execute on function public.list_content_reports(text, int) to authenticated;

create or replace function public.resolve_content_report(
  p_report_id uuid,
  p_status text,
  p_note text default ''
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_app_moderator() then
    raise exception 'Not a moderator';
  end if;
  if p_status not in ('resolved', 'dismissed', 'open') then
    raise exception 'Invalid status';
  end if;

  update public.content_reports
  set
    status = p_status,
    resolution_note = left(coalesce(p_note, ''), 500),
    resolved_at = case when p_status = 'open' then null else now() end,
    resolved_by = case when p_status = 'open' then null else auth.uid() end
  where id = p_report_id;

  if not found then
    raise exception 'Report not found';
  end if;
end;
$$;

grant execute on function public.resolve_content_report(uuid, text, text) to authenticated;

-- Soft-delete / deactivate a listing from the moderation queue.
create or replace function public.moderator_deactivate_listing(p_listing_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_app_moderator() then
    raise exception 'Not a moderator';
  end if;

  update public.listings
  set is_active = false, updated_at = now()
  where id = p_listing_id;

  if not found then
    raise exception 'Listing not found';
  end if;
end;
$$;

grant execute on function public.moderator_deactivate_listing(uuid) to authenticated;

-- To add yourself as moderator later:
-- insert into public.app_moderators (user_id)
-- select id from public.profiles where lower(login) = lower('your_login')
-- on conflict do nothing;
