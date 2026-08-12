-- Features v14: community channels catalog.
-- Featured public channels (#frontend, #ищу-кофаундера, …) for the Board tab.
-- Apply in Supabase SQL editor after features_v13.

alter table public.conversations
  add column if not exists category text,
  add column if not exists is_featured boolean not null default false;

create index if not exists conversations_featured_idx
  on public.conversations (is_featured, category)
  where is_featured;

-- Stable UUIDs so the client can always join the same rooms.
-- created_by = Murkot bot when the bot profile exists, otherwise null.
do $$
declare
  bot_id uuid := 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeee01';
  owner_id uuid;
begin
  if exists (select 1 from public.profiles p where p.id = bot_id) then
    owner_id := bot_id;
  else
    owner_id := null;
  end if;

  insert into public.conversations (
    id, type, name, description, avatar_emoji, created_by, category, is_featured, last_activity
  )
  values
    -- type=group so every member can post (channels are admin-only broadcasts).
    ('aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeef01', 'group', '#frontend',
     'Вёрстка, React, Vue, CSS и фронтенд-архитектура', '🖥️', owner_id, 'dev', true, now()),
    ('aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeef02', 'group', '#backend',
     'API, базы данных, серверная архитектура', '⚙️', owner_id, 'dev', true, now()),
    ('aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeef03', 'group', '#mobile',
     'Flutter, React Native, Android, iOS', '📱', owner_id, 'dev', true, now()),
    ('aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeef04', 'group', '#devops',
     'CI/CD, облака, инфраструктура и SRE', '☁️', owner_id, 'dev', true, now()),
    ('aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeef05', 'group', '#gamedev',
     'Игры, Unity, Unreal, геймдизайн', '🎮', owner_id, 'dev', true, now()),
    ('aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeef06', 'group', '#design',
     'UI/UX, продуктовый дизайн, портфолио', '🎨', owner_id, 'creative', true, now()),
    ('aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeef07', 'group', '#ищу-кофаундера',
     'Идеи стартапов и поиск партнёров', '🚀', owner_id, 'startup', true, now()),
    ('aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeef08', 'group', '#ревью-резюме',
     'Разбор CV, LinkedIn и портфолио', '📄', owner_id, 'career', true, now()),
    ('aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeef09', 'group', '#фриланс',
     'Заказы, ставки, клиенты и опыт фриланса', '💼', owner_id, 'career', true, now()),
    ('aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeef0a', 'group', '#общий',
     'Свободное общение айтишников СНГ', '💬', owner_id, 'general', true, now())
  on conflict (id) do update set
    name = excluded.name,
    description = excluded.description,
    avatar_emoji = excluded.avatar_emoji,
    category = excluded.category,
    type = excluded.type,
    is_featured = true;
end $$;

-- Ensure the bot is a member/admin of each featured channel (if bot profile exists).
insert into public.conversation_members (conversation_id, user_id, role)
select c.id, 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeee01', 'admin'
from public.conversations c
where c.is_featured
  and exists (
    select 1 from public.profiles p
    where p.id = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeee01'
  )
on conflict (conversation_id, user_id) do nothing;

create or replace function public.list_community_channels()
returns table (
  id uuid,
  type text,
  name text,
  description text,
  avatar_emoji text,
  avatar_url text,
  category text,
  member_count bigint,
  is_member boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  return query
  select
    c.id,
    c.type,
    c.name,
    c.description,
    c.avatar_emoji,
    c.avatar_url,
    c.category,
    (
      select count(*)::bigint
      from public.conversation_members m
      where m.conversation_id = c.id
    ) as member_count,
    exists (
      select 1
      from public.conversation_members m
      where m.conversation_id = c.id and m.user_id = uid
    ) as is_member
  from public.conversations c
  where c.is_featured = true
    and c.type in ('group', 'channel')
  order by
    case c.category
      when 'startup' then 0
      when 'career' then 1
      when 'dev' then 2
      when 'creative' then 3
      else 4
    end,
    c.name;
end;
$$;

grant execute on function public.list_community_channels() to authenticated;
