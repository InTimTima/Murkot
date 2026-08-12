-- Features v15: community rooms are discussion groups (members can post).
-- Featured catalog entries were seeded as channels (admin-only posting).
-- Convert them to groups and refresh the list RPC.
-- Apply in Supabase SQL editor after features_v14.

update public.conversations
set type = 'group'
where is_featured = true
  and type = 'channel';

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
