-- Features v17: push events (match), reports, hide listings,
-- analytics, private group invites.
-- Apply AFTER features_v16.

-- ─── 1. Generic push outbox (webhook → Edge Function push-on-event) ──
create table if not exists public.push_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists push_events_user_idx on public.push_events (user_id);
alter table public.push_events enable row level security;
-- No client policies: only service role / security definer writers.

create or replace function public.enqueue_push_event(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_data jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null then
    return;
  end if;
  insert into public.push_events (user_id, title, body, data)
  values (p_user_id, p_title, p_body, coalesce(p_data, '{}'::jsonb));
end;
$$;

-- Mutual match → push both users.
create or replace function public.swipe_match(p_target_id uuid, p_liked boolean)
returns table (is_match boolean)
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  mutual boolean := false;
  my_login text;
  their_login text;
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

  if mutual then
    select login into my_login from public.profiles where id = uid;
    select login into their_login from public.profiles where id = p_target_id;
    perform public.enqueue_push_event(
      p_target_id,
      'Это матч!',
      coalesce(my_login, 'Кто-то') || ' тоже заинтересован(а). Откройте чат.',
      jsonb_build_object('type', 'match', 'peer_id', uid, 'peer_login', my_login)
    );
    perform public.enqueue_push_event(
      uid,
      'Это матч!',
      coalesce(their_login, 'Кто-то') || ' тоже заинтересован(а). Откройте чат.',
      jsonb_build_object('type', 'match', 'peer_id', p_target_id, 'peer_login', their_login)
    );
  end if;

  return query select mutual;
end;
$$;

grant execute on function public.swipe_match(uuid, boolean) to authenticated;

-- Webhook setup (Dashboard → Database → Webhooks):
--   Table: push_events, Events: INSERT
--   URL: https://<project>.supabase.co/functions/v1/push-on-event
--   HTTP Headers: Authorization: Bearer <service_role or anon as configured>

-- ─── 2. Content reports ──────────────────────────────────────
create table if not exists public.content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  target_type text not null check (target_type in ('listing', 'project', 'profile', 'message')),
  target_id text not null,
  reason text not null default '',
  created_at timestamptz not null default now(),
  constraint content_reports_unique unique (reporter_id, target_type, target_id)
);

alter table public.content_reports enable row level security;

drop policy if exists "Users can insert own reports" on public.content_reports;
create policy "Users can insert own reports"
  on public.content_reports for insert to authenticated
  with check (auth.uid() = reporter_id);

drop policy if exists "Users can view own reports" on public.content_reports;
create policy "Users can view own reports"
  on public.content_reports for select to authenticated
  using (auth.uid() = reporter_id);

create or replace function public.submit_report(
  p_target_type text,
  p_target_id text,
  p_reason text default ''
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if p_target_type not in ('listing', 'project', 'profile', 'message') then
    raise exception 'Invalid target type';
  end if;
  if trim(p_target_id) = '' then
    raise exception 'Invalid target';
  end if;

  insert into public.content_reports (reporter_id, target_type, target_id, reason)
  values (auth.uid(), p_target_type, trim(p_target_id), left(coalesce(p_reason, ''), 500))
  on conflict (reporter_id, target_type, target_id) do update
    set reason = excluded.reason,
        created_at = now();
end;
$$;

grant execute on function public.submit_report(text, text, text) to authenticated;

-- ─── 3. Hide listings for me ───────────────────────────────
create table if not exists public.hidden_listings (
  user_id uuid not null references public.profiles (id) on delete cascade,
  listing_id uuid not null references public.listings (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, listing_id)
);

alter table public.hidden_listings enable row level security;

drop policy if exists "Users manage own hidden listings" on public.hidden_listings;
create policy "Users manage own hidden listings"
  on public.hidden_listings for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ─── 4. Analytics (append-only, own rows) ────────────────
create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles (id) on delete set null,
  name text not null,
  props jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists analytics_events_name_idx
  on public.analytics_events (name, created_at desc);

alter table public.analytics_events enable row level security;

drop policy if exists "Users can insert own analytics" on public.analytics_events;
create policy "Users can insert own analytics"
  on public.analytics_events for insert to authenticated
  with check (auth.uid() = user_id);

create or replace function public.track_event(p_name text, p_props jsonb default '{}'::jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return;
  end if;
  if trim(coalesce(p_name, '')) = '' then
    return;
  end if;
  insert into public.analytics_events (user_id, name, props)
  values (auth.uid(), left(trim(p_name), 80), coalesce(p_props, '{}'::jsonb));
end;
$$;

grant execute on function public.track_event(text, jsonb) to authenticated;

-- ─── 5. Private group invites ────────────────────────────
create table if not exists public.conversation_invites (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  token text not null unique,
  created_by uuid not null references public.profiles (id) on delete cascade,
  expires_at timestamptz not null default (now() + interval '7 days'),
  max_uses int not null default 50,
  use_count int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists conversation_invites_conv_idx
  on public.conversation_invites (conversation_id);

alter table public.conversation_invites enable row level security;

drop policy if exists "Admins manage invites" on public.conversation_invites;
create policy "Admins manage invites"
  on public.conversation_invites for all to authenticated
  using (public.is_conversation_admin(conversation_id))
  with check (public.is_conversation_admin(conversation_id));

create or replace function public.create_conversation_invite(
  p_conversation_id uuid,
  p_days int default 7
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token text;
  v_type text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if not public.is_conversation_admin(p_conversation_id) then
    raise exception 'Not allowed';
  end if;

  select type into v_type from public.conversations where id = p_conversation_id;
  if v_type is null or v_type = 'direct' then
    raise exception 'Invalid conversation';
  end if;

  v_token := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  insert into public.conversation_invites (
    conversation_id, token, created_by, expires_at
  ) values (
    p_conversation_id,
    v_token,
    auth.uid(),
    now() + make_interval(days => greatest(1, least(coalesce(p_days, 7), 30)))
  );
  return v_token;
end;
$$;

grant execute on function public.create_conversation_invite(uuid, int) to authenticated;

create or replace function public.redeem_conversation_invite(p_token text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inv public.conversation_invites%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_inv
  from public.conversation_invites
  where token = trim(p_token)
  for update;

  if not found then
    raise exception 'Invite not found';
  end if;
  if v_inv.expires_at < now() then
    raise exception 'Invite expired';
  end if;
  if v_inv.use_count >= v_inv.max_uses then
    raise exception 'Invite exhausted';
  end if;

  insert into public.conversation_members (conversation_id, user_id, role)
  values (v_inv.conversation_id, auth.uid(), 'member')
  on conflict (conversation_id, user_id) do nothing;

  update public.conversation_invites
  set use_count = use_count + 1
  where id = v_inv.id;

  return v_inv.conversation_id;
end;
$$;

grant execute on function public.redeem_conversation_invite(text) to authenticated;

-- Admins can toggle is_public for discoverability.
create or replace function public.set_conversation_public(
  p_conversation_id uuid,
  p_is_public boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if not public.is_conversation_admin(p_conversation_id) then
    raise exception 'Not allowed';
  end if;
  update public.conversations
  set is_public = coalesce(p_is_public, false)
  where id = p_conversation_id
    and type in ('group', 'channel');
end;
$$;

grant execute on function public.set_conversation_public(uuid, boolean) to authenticated;

-- ─── 6. Ensure profiles/listings grants (idempotent after partial v16) ──
grant select (
  id, login, status, avatar_url, avatar_emoji, profile_wallpaper_id,
  custom_wallpaper_url, birthday, created_at, updated_at,
  last_seen_at, is_bot, dev_status, skills, experience_level,
  github_url, portfolio_url, city
) on table public.profiles to authenticated;

grant update (
  login, status, avatar_url, avatar_emoji, profile_wallpaper_id,
  custom_wallpaper_url, birthday, updated_at,
  dev_status, skills, experience_level, github_url, portfolio_url, city
) on table public.profiles to authenticated;

grant insert (
  id, login, email, status, avatar_url, avatar_emoji, profile_wallpaper_id,
  custom_wallpaper_url, birthday, dev_status, skills, experience_level,
  github_url, portfolio_url, city, is_bot
) on table public.profiles to authenticated;

grant delete on table public.profiles to authenticated;
grant select, insert, update, delete on table public.listings to authenticated;
