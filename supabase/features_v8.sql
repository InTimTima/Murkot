-- Features v8: public group/channel search + join.
-- Apply in Supabase SQL editor after features_v7.

-- Search public groups/channels by name. SECURITY DEFINER so users can
-- discover conversations they are not members of (RLS hides them otherwise).
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
    and c.name ilike '%' || search_query || '%'
  order by c.last_activity desc
  limit 30;
$$;

grant execute on function public.search_public_conversations(text, text) to authenticated;

-- Join a public group/channel as a regular member.
create or replace function public.join_conversation(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type text;
begin
  select type into v_type
  from public.conversations
  where id = p_conversation_id;

  if v_type is null then
    raise exception 'Conversation not found';
  end if;
  if v_type = 'direct' then
    raise exception 'Cannot join a direct chat';
  end if;

  insert into public.conversation_members (conversation_id, user_id, role)
  values (p_conversation_id, auth.uid(), 'member')
  on conflict (conversation_id, user_id) do nothing;
end;
$$;

grant execute on function public.join_conversation(uuid) to authenticated;
