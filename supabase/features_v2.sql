-- Search users, direct chats, TujhBot
-- Run in Supabase SQL Editor after schema.sql

alter table public.profiles
  add column if not exists is_bot boolean not null default false;

-- ─── Search users by login ──────────────────────────────────

create or replace function public.search_users(search_query text)
returns table (
  id uuid,
  login text,
  status text,
  avatar_emoji text,
  avatar_url text,
  is_bot boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.login,
    p.status,
    p.avatar_emoji,
    p.avatar_url,
    p.is_bot
  from public.profiles p
  where auth.uid() is not null
    and p.id <> auth.uid()
    and length(trim(search_query)) >= 1
    and p.login ilike '%' || trim(search_query) || '%'
  order by
    p.is_bot desc,
    case when lower(p.login) = lower(trim(search_query)) then 0 else 1 end,
    p.login
  limit 30;
$$;

grant execute on function public.search_users(text) to authenticated;

-- ─── Get or create 1:1 direct chat ──────────────────────────

create or replace function public.get_or_create_direct_chat(other_user_id uuid)
returns public.conversations
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  conv public.conversations;
  other_login text;
  other_emoji text;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if other_user_id is null or other_user_id = uid then
    raise exception 'Invalid user';
  end if;

  select p.login, p.avatar_emoji
    into other_login, other_emoji
  from public.profiles p
  where p.id = other_user_id;

  if other_login is null then
    raise exception 'User not found';
  end if;

  select c.* into conv
  from public.conversations c
  where c.type = 'direct'
    and exists (
      select 1 from public.conversation_members m1
      where m1.conversation_id = c.id and m1.user_id = uid
    )
    and exists (
      select 1 from public.conversation_members m2
      where m2.conversation_id = c.id and m2.user_id = other_user_id
    )
    and (
      select count(*) from public.conversation_members m
      where m.conversation_id = c.id
    ) = 2
  limit 1;

  if conv.id is not null then
    return conv;
  end if;

  insert into public.conversations (type, name, avatar_emoji, created_by, last_activity)
  values ('direct', other_login, coalesce(other_emoji, '💬'), uid, now())
  returning * into conv;

  insert into public.conversation_members (conversation_id, user_id, role)
  values
    (conv.id, uid, 'member'),
    (conv.id, other_user_id, 'member');

  return conv;
end;
$$;

grant execute on function public.get_or_create_direct_chat(uuid) to authenticated;

-- ─── Seed TujhBot ───────────────────────────────────────────

do $$
declare
  bot_id uuid := 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeee01';
begin
  if not exists (select 1 from auth.users where id = bot_id) then
    insert into auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      confirmation_token,
      recovery_token,
      email_change_token_new,
      email_change
    ) values (
      '00000000-0000-0000-0000-000000000000',
      bot_id,
      'authenticated',
      'authenticated',
      'tujhbot@tujh.local',
      crypt('bot-login-disabled', gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"login":"TujhBot","avatar_emoji":"🤖"}'::jsonb,
      now(),
      now(),
      '',
      '',
      '',
      ''
    );
  end if;

  if not exists (
    select 1 from auth.identities
    where user_id = bot_id and provider = 'email'
  ) then
    insert into auth.identities (
      id,
      user_id,
      identity_data,
      provider,
      provider_id,
      last_sign_in_at,
      created_at,
      updated_at
    ) values (
      bot_id,
      bot_id,
      jsonb_build_object(
        'sub', bot_id::text,
        'email', 'tujhbot@tujh.local',
        'email_verified', true
      ),
      'email',
      bot_id::text,
      now(),
      now(),
      now()
    );
  end if;

  insert into public.profiles (
    id, login, email, avatar_emoji, status, is_bot
  ) values (
    bot_id, 'TujhBot', 'tujhbot@tujh.local', '🤖', 'Всегда на связи', true
  )
  on conflict (id) do update set
    login = excluded.login,
    avatar_emoji = excluded.avatar_emoji,
    status = excluded.status,
    is_bot = true;
end $$;

-- ─── Bot auto-reply (DB trigger → Realtime websocket) ───────

create or replace function public.bot_auto_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  bot_id uuid := 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeee01';
  is_dm boolean;
  has_bot boolean;
  reply text;
  msg text;
begin
  if new.sender_id = bot_id then
    return new;
  end if;

  select (c.type = 'direct') into is_dm
  from public.conversations c
  where c.id = new.conversation_id;

  if not coalesce(is_dm, false) then
    return new;
  end if;

  select exists (
    select 1
    from public.conversation_members cm
    where cm.conversation_id = new.conversation_id
      and cm.user_id = bot_id
  ) into has_bot;

  if not has_bot then
    return new;
  end if;

  msg := lower(coalesce(new.content, ''));

  reply := case
    when msg ~ '(привет|здравствуй|hello|hi)' then
      'Привет! Я TujhBot 🤖 Могу подсказать команды — напиши «помощь».'
    when msg ~ '(помощь|help|команд)' then
      'Команды: привет, помощь, время, пинг, статус.'
    when msg ~ '(время|time|дата|date)' then
      'Сейчас: ' || to_char(timezone('UTC', now()), 'YYYY-MM-DD HH24:MI') || ' UTC'
    when msg ~ '(пинг|ping)' then
      'Понг! Realtime работает через WebSocket Supabase.'
    when msg ~ '(статус|status)' then
      'Я онлайн и отвечаю мгновенно через триггер в Postgres.'
    else
      'Принял: «' || left(new.content, 140) || '». Напиши «помощь» для списка команд.'
  end;

  insert into public.messages (conversation_id, sender_id, type, content)
  values (new.conversation_id, bot_id, 'text', reply);

  return new;
end;
$$;

drop trigger if exists messages_bot_auto_reply on public.messages;
create trigger messages_bot_auto_reply
  after insert on public.messages
  for each row execute function public.bot_auto_reply();
