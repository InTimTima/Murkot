-- Full backend schema for Tujh Messenger
-- Run in Supabase Dashboard → SQL Editor (can re-run safely)

create extension if not exists "pgcrypto";

-- ─── Profiles ───────────────────────────────────────────────

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  login text not null unique,
  email text not null,
  status text not null default '',
  avatar_emoji text,
  avatar_url text,
  profile_wallpaper_id text not null default 'blue',
  custom_wallpaper_url text,
  birthday date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists profiles_login_idx on public.profiles (lower(login));
create index if not exists profiles_email_idx on public.profiles (lower(email));

alter table public.profiles enable row level security;

drop policy if exists "Profiles are viewable by authenticated users" on public.profiles;
create policy "Profiles are viewable by authenticated users"
  on public.profiles for select to authenticated using (true);

drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile"
  on public.profiles for insert to authenticated
  with check (auth.uid() = id);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
  on public.profiles for update to authenticated
  using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "Users can delete own profile" on public.profiles;
create policy "Users can delete own profile"
  on public.profiles for delete to authenticated
  using (auth.uid() = id);

create or replace function public.handle_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.handle_updated_at();

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, login, email, avatar_emoji, status)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'login', split_part(new.email, '@', 1)),
    new.email,
    coalesce(new.raw_user_meta_data ->> 'avatar_emoji', '😀'),
    'В сети'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.is_login_available(desired_login text)
returns boolean language sql security definer set search_path = public as $$
  select not exists (
    select 1 from public.profiles where lower(login) = lower(desired_login)
  );
$$;

create or replace function public.delete_own_account()
returns void language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  delete from auth.users where id = uid;
end;
$$;

grant execute on function public.is_login_available(text) to anon, authenticated;
grant execute on function public.delete_own_account() to authenticated;

-- ─── Conversations ──────────────────────────────────────────

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('direct', 'group', 'channel')),
  name text not null,
  description text not null default '',
  avatar_emoji text,
  avatar_url text,
  last_message text not null default '',
  last_message_sender text,
  last_activity timestamptz not null default now(),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists conversations_last_activity_idx
  on public.conversations (last_activity desc);

create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null default 'member' check (role in ('admin', 'member')),
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create index if not exists conversation_members_user_idx
  on public.conversation_members (user_id);

-- ─── Messages ───────────────────────────────────────────────

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  type text not null default 'text',
  content text not null default '',
  is_edited boolean not null default false,
  is_deleted_for_all boolean not null default false,
  view_count integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists messages_conversation_created_idx
  on public.messages (conversation_id, created_at);

create table if not exists public.message_comments (
  id uuid primary key default gen_random_uuid(),
  post_message_id uuid not null references public.messages (id) on delete cascade,
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);

create index if not exists message_comments_post_idx
  on public.message_comments (post_message_id, created_at);

create table if not exists public.message_reactions (
  message_id uuid not null references public.messages (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  emoji text not null,
  primary key (message_id, user_id)
);

create table if not exists public.message_hides (
  message_id uuid not null references public.messages (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  primary key (message_id, user_id)
);

create table if not exists public.message_pins (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages (id) on delete cascade,
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  pinned_by uuid not null references public.profiles (id) on delete cascade,
  for_everyone boolean not null default false,
  created_at timestamptz not null default now()
);

create unique index if not exists message_pins_everyone_uq
  on public.message_pins (message_id)
  where for_everyone = true;

create unique index if not exists message_pins_personal_uq
  on public.message_pins (message_id, pinned_by)
  where for_everyone = false;

create table if not exists public.message_reads (
  message_id uuid not null references public.messages (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

create table if not exists public.blocked_users (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_login text not null,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_login)
);

-- ─── Helper functions ───────────────────────────────────────

create or replace function public.is_conversation_member(conv_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.conversation_members
    where conversation_id = conv_id and user_id = auth.uid()
  );
$$;

create or replace function public.is_conversation_admin(conv_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.conversation_members
    where conversation_id = conv_id
      and user_id = auth.uid()
      and role = 'admin'
  );
$$;

grant execute on function public.is_conversation_member(uuid) to authenticated;
grant execute on function public.is_conversation_admin(uuid) to authenticated;

create or replace function public.create_conversation(
  p_type text,
  p_name text,
  p_emoji text default null
)
returns public.conversations
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  conv public.conversations;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_type not in ('direct', 'group', 'channel') then
    raise exception 'Invalid conversation type';
  end if;

  insert into public.conversations (type, name, avatar_emoji, created_by, last_activity)
  values (p_type, trim(p_name), coalesce(p_emoji, '💬'), uid, now())
  returning * into conv;

  insert into public.conversation_members (conversation_id, user_id, role)
  values (conv.id, uid, 'admin');

  return conv;
end;
$$;

grant execute on function public.create_conversation(text, text, text) to authenticated;

create or replace function public.touch_conversation_preview()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  preview text;
  sender_login text;
begin
  if tg_op = 'INSERT' and not new.is_deleted_for_all then
    select login into sender_login from public.profiles where id = new.sender_id;
    preview := case
      when new.type = 'text' then left(new.content, 200)
      when new.type = 'voice' then '🎤 Голосовое'
      when new.type = 'video' then '🎬 Видео'
      when new.type = 'image' then '📷 Фото'
      when new.type = 'music' then '🎵 Музыка'
      when new.type = 'sticker' then '🎭 Стикер'
      when new.type = 'emoji' then '😀 Эмодзи'
      when new.type = 'gif' then 'GIF'
      when new.type = 'file' then '📎 Файл'
      else left(new.content, 200)
    end;

    update public.conversations
    set last_message = preview,
        last_message_sender = sender_login,
        last_activity = new.created_at
    where id = new.conversation_id;
  end if;
  return new;
end;
$$;

drop trigger if exists messages_touch_conversation on public.messages;
create trigger messages_touch_conversation
  after insert on public.messages
  for each row execute function public.touch_conversation_preview();

-- ─── RLS ────────────────────────────────────────────────────

alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.message_comments enable row level security;
alter table public.message_reactions enable row level security;
alter table public.message_hides enable row level security;
alter table public.message_pins enable row level security;
alter table public.message_reads enable row level security;
alter table public.blocked_users enable row level security;

drop policy if exists "Members can view conversations" on public.conversations;
create policy "Members can view conversations"
  on public.conversations for select to authenticated
  using (public.is_conversation_member(id));

drop policy if exists "Members can update conversations" on public.conversations;
create policy "Members can update conversations"
  on public.conversations for update to authenticated
  using (public.is_conversation_member(id));

drop policy if exists "Admins can delete conversations" on public.conversations;
create policy "Admins can delete conversations"
  on public.conversations for delete to authenticated
  using (public.is_conversation_admin(id));

drop policy if exists "Members can view members" on public.conversation_members;
create policy "Members can view members"
  on public.conversation_members for select to authenticated
  using (public.is_conversation_member(conversation_id));

drop policy if exists "Users can leave conversations" on public.conversation_members;
create policy "Users can leave conversations"
  on public.conversation_members for delete to authenticated
  using (user_id = auth.uid() or public.is_conversation_admin(conversation_id));

drop policy if exists "Admins can add members" on public.conversation_members;
create policy "Admins can add members"
  on public.conversation_members for insert to authenticated
  with check (
    public.is_conversation_admin(conversation_id)
    or user_id = auth.uid()
  );

drop policy if exists "Admins can update members" on public.conversation_members;
create policy "Admins can update members"
  on public.conversation_members for update to authenticated
  using (public.is_conversation_admin(conversation_id));

drop policy if exists "Members can view messages" on public.messages;
create policy "Members can view messages"
  on public.messages for select to authenticated
  using (public.is_conversation_member(conversation_id));

drop policy if exists "Members can send messages" on public.messages;
create policy "Members can send messages"
  on public.messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and public.is_conversation_member(conversation_id)
    and (
      exists (
        select 1 from public.conversations c
        where c.id = conversation_id and c.type <> 'channel'
      )
      or public.is_conversation_admin(conversation_id)
    )
  );

drop policy if exists "Senders can update own messages" on public.messages;
create policy "Senders can update own messages"
  on public.messages for update to authenticated
  using (
    sender_id = auth.uid()
    or public.is_conversation_member(conversation_id)
  );

drop policy if exists "Members can view comments" on public.message_comments;
create policy "Members can view comments"
  on public.message_comments for select to authenticated
  using (public.is_conversation_member(conversation_id));

drop policy if exists "Members can add comments" on public.message_comments;
create policy "Members can add comments"
  on public.message_comments for insert to authenticated
  with check (
    sender_id = auth.uid()
    and public.is_conversation_member(conversation_id)
  );

drop policy if exists "Members can view reactions" on public.message_reactions;
create policy "Members can view reactions"
  on public.message_reactions for select to authenticated
  using (
    exists (
      select 1 from public.messages m
      where m.id = message_id and public.is_conversation_member(m.conversation_id)
    )
  );

drop policy if exists "Users manage own reactions" on public.message_reactions;
create policy "Users manage own reactions"
  on public.message_reactions for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "Users manage own hides" on public.message_hides;
create policy "Users manage own hides"
  on public.message_hides for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "Members can view pins" on public.message_pins;
create policy "Members can view pins"
  on public.message_pins for select to authenticated
  using (public.is_conversation_member(conversation_id));

drop policy if exists "Members can pin" on public.message_pins;
create policy "Members can pin"
  on public.message_pins for insert to authenticated
  with check (
    pinned_by = auth.uid()
    and public.is_conversation_member(conversation_id)
  );

drop policy if exists "Users can unpin" on public.message_pins;
create policy "Users can unpin"
  on public.message_pins for delete to authenticated
  using (
    pinned_by = auth.uid()
    or (for_everyone = true and public.is_conversation_admin(conversation_id))
  );

drop policy if exists "Members can view reads" on public.message_reads;
create policy "Members can view reads"
  on public.message_reads for select to authenticated
  using (
    exists (
      select 1 from public.messages m
      where m.id = message_id and public.is_conversation_member(m.conversation_id)
    )
  );

drop policy if exists "Users manage own reads" on public.message_reads;
create policy "Users manage own reads"
  on public.message_reads for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "Users manage own blocks" on public.blocked_users;
create policy "Users manage own blocks"
  on public.blocked_users for all to authenticated
  using (blocker_id = auth.uid())
  with check (blocker_id = auth.uid());

-- ─── Realtime ───────────────────────────────────────────────

do $$
begin
  begin
    alter publication supabase_realtime add table public.conversations;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.conversation_members;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.messages;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.message_comments;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.message_reactions;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.message_pins;
  exception when duplicate_object then null;
  end;
end $$;

-- ─── Storage (avatars) ──────────────────────────────────────

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "Avatar images are public" on storage.objects;
create policy "Avatar images are public"
  on storage.objects for select
  using (bucket_id = 'avatars');

drop policy if exists "Users can upload own avatars" on storage.objects;
create policy "Users can upload own avatars"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Users can update own avatars" on storage.objects;
create policy "Users can update own avatars"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Users can delete own avatars" on storage.objects;
create policy "Users can delete own avatars"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
