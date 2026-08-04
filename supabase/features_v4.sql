-- Blacklist enforcement + reply_to messages
-- Run after features_v3.sql

alter table public.messages
  add column if not exists reply_to_id uuid references public.messages (id) on delete set null;

create index if not exists messages_reply_to_idx on public.messages (reply_to_id);

-- Block check for direct chats (either direction)
create or replace function public.enforce_dm_not_blocked()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  conv_type text;
  sender_login text;
  other_login text;
begin
  select c.type into conv_type
  from public.conversations c
  where c.id = new.conversation_id;

  if conv_type is distinct from 'direct' then
    return new;
  end if;

  select login into sender_login from public.profiles where id = new.sender_id;

  select p.login into other_login
  from public.conversation_members cm
  join public.profiles p on p.id = cm.user_id
  where cm.conversation_id = new.conversation_id
    and cm.user_id <> new.sender_id
  limit 1;

  if other_login is null then
    return new;
  end if;

  if exists (
    select 1 from public.blocked_users
    where (blocker_id = new.sender_id and blocked_login = other_login)
       or (
         blocker_id = (
           select id from public.profiles where login = other_login limit 1
         )
         and blocked_login = sender_login
       )
  ) then
    raise exception 'User is blocked';
  end if;

  return new;
end;
$$;

drop trigger if exists messages_enforce_dm_block on public.messages;
create trigger messages_enforce_dm_block
  before insert on public.messages
  for each row execute function public.enforce_dm_not_blocked();

-- Hide blocked users from search
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
    and not exists (
      select 1 from public.blocked_users b
      where b.blocker_id = auth.uid()
        and lower(b.blocked_login) = lower(p.login)
    )
    and not exists (
      select 1 from public.blocked_users b
      join public.profiles me on me.id = auth.uid()
      where b.blocker_id = p.id
        and lower(b.blocked_login) = lower(me.login)
    )
  order by
    p.is_bot desc,
    case when lower(p.login) = lower(trim(search_query)) then 0 else 1 end,
    p.login
  limit 30;
$$;

-- Realtime for read receipts
do $$
begin
  begin
    alter publication supabase_realtime add table public.message_reads;
  exception when duplicate_object then null;
  end;
end $$;
