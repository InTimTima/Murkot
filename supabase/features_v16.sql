-- Features v16: security hardening from code review.
-- REQUIRED before any public / friend soft-launch.
-- Apply in Supabase SQL editor AFTER features_v15 (and earlier v10–v14 if missing).
--
-- Checklist after apply:
--   [ ] edit another user's message → denied
--   [ ] search/join private group → denied
--   [ ] select match_swipes as target → only own swipes as swiper
--   [ ] select profiles.email of another user → missing / denied
--   [ ] non-admin conversation rename → denied
--
-- Fixes: messages UPDATE, is_public groups, match_swipes leak,
-- profiles email exposure, conversation UPDATE scope.

-- ─── 1. Messages: only sender may update content ─────────────
drop policy if exists "Senders can update own messages" on public.messages;
create policy "Senders can update own messages"
  on public.messages for update to authenticated
  using (sender_id = auth.uid())
  with check (sender_id = auth.uid());

-- View-count bumps for any member (was abusing unrestricted UPDATE).
create or replace function public.increment_message_view_count(p_message_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conv uuid;
  v_count integer;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select conversation_id, view_count
    into v_conv, v_count
  from public.messages
  where id = p_message_id;

  if v_conv is null then
    raise exception 'Message not found';
  end if;
  if not public.is_conversation_member(v_conv) then
    raise exception 'Not a member';
  end if;

  update public.messages
  set view_count = coalesce(view_count, 0) + 1
  where id = p_message_id
  returning view_count into v_count;

  return v_count;
end;
$$;

grant execute on function public.increment_message_view_count(uuid) to authenticated;

-- Soft-delete for everyone: sender or conversation admin only.
create or replace function public.soft_delete_message_for_all(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conv uuid;
  v_sender uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select conversation_id, sender_id into v_conv, v_sender
  from public.messages
  where id = p_message_id;

  if v_conv is null then
    raise exception 'Message not found';
  end if;
  if v_sender <> auth.uid() and not public.is_conversation_admin(v_conv) then
    raise exception 'Not allowed';
  end if;

  update public.messages
  set is_deleted_for_all = true, content = ''
  where id = p_message_id;
end;
$$;

grant execute on function public.soft_delete_message_for_all(uuid) to authenticated;

-- ─── 2. Public / private conversations ───────────────────────
alter table public.conversations
  add column if not exists is_public boolean not null default false;

-- Featured community rooms are public join targets.
update public.conversations
set is_public = true
where is_featured = true;

create or replace function public.search_public_conversations(
  search_query text,
  p_type text
)
returns table (
  id uuid,
  type text,
  name text,
  description text,
  avatar_emoji text,
  avatar_url text,
  member_count bigint,
  is_member boolean
)
language sql
security definer
set search_path = public
as $$
  select
    c.id,
    c.type,
    c.name,
    coalesce(c.description, ''),
    c.avatar_emoji,
    c.avatar_url,
    (
      select count(*)
      from public.conversation_members m
      where m.conversation_id = c.id
    ),
    exists (
      select 1
      from public.conversation_members m
      where m.conversation_id = c.id
        and m.user_id = auth.uid()
    )
  from public.conversations c
  where c.type = p_type
    and c.type in ('group', 'channel')
    and c.is_public = true
    and c.name ilike '%' || search_query || '%'
  order by c.last_activity desc
  limit 30;
$$;

create or replace function public.join_conversation(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type text;
  v_public boolean;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select type, is_public into v_type, v_public
  from public.conversations
  where id = p_conversation_id;

  if v_type is null then
    raise exception 'Conversation not found';
  end if;
  if v_type = 'direct' then
    raise exception 'Cannot join a direct chat';
  end if;
  if coalesce(v_public, false) = false then
    raise exception 'Conversation is private';
  end if;

  insert into public.conversation_members (conversation_id, user_id, role)
  values (p_conversation_id, auth.uid(), 'member')
  on conflict (conversation_id, user_id) do nothing;
end;
$$;

-- Members may not self-insert into private rooms via raw table access.
drop policy if exists "Admins can add members" on public.conversation_members;
create policy "Admins can add members"
  on public.conversation_members for insert to authenticated
  with check (
    public.is_conversation_admin(conversation_id)
    or (
      user_id = auth.uid()
      and exists (
        select 1 from public.conversations c
        where c.id = conversation_id
          and c.is_public = true
          and c.type in ('group', 'channel')
      )
    )
  );

-- ─── 3. Conversation UPDATE: admins only (not every member) ──
drop policy if exists "Members can update conversations" on public.conversations;
drop policy if exists "Admins can update conversations" on public.conversations;
create policy "Admins can update conversations"
  on public.conversations for update to authenticated
  using (public.is_conversation_admin(id))
  with check (public.is_conversation_admin(id));

-- Preview/last-message updates from triggers run as definer/owner — OK.
-- Client last-activity bumps that relied on member UPDATE need an RPC:
create or replace function public.touch_conversation_activity(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if not public.is_conversation_member(p_conversation_id) then
    raise exception 'Not a member';
  end if;
  update public.conversations
  set last_activity = now()
  where id = p_conversation_id;
end;
$$;

grant execute on function public.touch_conversation_activity(uuid) to authenticated;

-- ─── 4. match_swipes: swiper-only SELECT ─────────────────────
drop policy if exists "Users can view own swipes" on public.match_swipes;
create policy "Users can view own swipes"
  on public.match_swipes for select to authenticated
  using (auth.uid() = swiper_id);

-- ─── 5. Profiles: no email directory dump ────────────────────
drop policy if exists "Authenticated users can view profiles" on public.profiles;
drop policy if exists "Users can view profiles" on public.profiles;
drop policy if exists "Users can view own profile" on public.profiles;
drop policy if exists "Users can view public profile columns" on public.profiles;

-- Directory view without email (owner rights, not invoker RLS).
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
  last_seen_at
from public.profiles;

grant select on public.public_profiles to authenticated;

create or replace function public.get_public_profile_by_login(p_login text)
returns setof public.public_profiles
language sql
security definer
set search_path = public
as $$
  select *
  from public.public_profiles
  where lower(login) = lower(trim(p_login))
  limit 1;
$$;

grant execute on function public.get_public_profile_by_login(text) to authenticated;

create or replace function public.get_own_profile()
returns setof public.profiles
language sql
security definer
set search_path = public
as $$
  select * from public.profiles where id = auth.uid();
$$;

grant execute on function public.get_own_profile() to authenticated;

-- Table grants: public columns only (no email) + open SELECT RLS for embeds.
revoke all on table public.profiles from authenticated;
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

create policy "Users can view public profile columns"
  on public.profiles for select to authenticated
  using (true);

-- ─── 6. updated_at triggers for listings/projects ────────────
do $$
begin
  if exists (
    select 1 from pg_proc where proname = 'handle_updated_at'
  ) then
    drop trigger if exists listings_updated_at on public.listings;
    create trigger listings_updated_at
      before update on public.listings
      for each row execute function public.handle_updated_at();

    drop trigger if exists projects_updated_at on public.projects;
    create trigger projects_updated_at
      before update on public.projects
      for each row execute function public.handle_updated_at();
  end if;
exception when undefined_table then
  null;
end $$;
