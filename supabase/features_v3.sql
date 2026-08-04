-- Media storage + group/channel member management
-- Run after features_v2.sql

-- ─── Chat media bucket ──────────────────────────────────────

insert into storage.buckets (id, name, public, file_size_limit)
values ('chat-media', 'chat-media', true, 52428800)
on conflict (id) do update set public = true;

drop policy if exists "Chat media is public" on storage.objects;
create policy "Chat media is public"
  on storage.objects for select
  using (bucket_id = 'chat-media');

drop policy if exists "Users upload own chat media" on storage.objects;
create policy "Users upload own chat media"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'chat-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Users update own chat media" on storage.objects;
create policy "Users update own chat media"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'chat-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Users delete own chat media" on storage.objects;
create policy "Users delete own chat media"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'chat-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ─── Add / remove members ───────────────────────────────────

create or replace function public.add_conversation_member(
  p_conversation_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  conv_type text;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  if not public.is_conversation_admin(p_conversation_id) then
    raise exception 'Only admins can add members';
  end if;

  select type into conv_type from public.conversations where id = p_conversation_id;
  if conv_type is null then
    raise exception 'Conversation not found';
  end if;
  if conv_type = 'direct' then
    raise exception 'Cannot add members to direct chat';
  end if;

  if not exists (select 1 from public.profiles where id = p_user_id) then
    raise exception 'User not found';
  end if;

  insert into public.conversation_members (conversation_id, user_id, role)
  values (p_conversation_id, p_user_id, 'member')
  on conflict do nothing;
end;
$$;

create or replace function public.add_conversation_member_by_login(
  p_conversation_id uuid,
  p_login text
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  target public.profiles;
begin
  select * into target
  from public.profiles
  where lower(login) = lower(trim(p_login))
  limit 1;

  if target.id is null then
    raise exception 'User not found';
  end if;

  perform public.add_conversation_member(p_conversation_id, target.id);
  return target;
end;
$$;

create or replace function public.remove_conversation_member(
  p_conversation_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  target_role text;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  if p_user_id <> uid and not public.is_conversation_admin(p_conversation_id) then
    raise exception 'Not allowed';
  end if;

  select role into target_role
  from public.conversation_members
  where conversation_id = p_conversation_id and user_id = p_user_id;

  if target_role is null then
    return;
  end if;

  if target_role = 'admin'
     and (
       select count(*) from public.conversation_members
       where conversation_id = p_conversation_id and role = 'admin'
     ) <= 1
     and p_user_id = uid then
    raise exception 'Cannot remove the last admin';
  end if;

  delete from public.conversation_members
  where conversation_id = p_conversation_id and user_id = p_user_id;
end;
$$;

create or replace function public.remove_conversation_member_by_login(
  p_conversation_id uuid,
  p_login text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_id uuid;
begin
  select id into target_id
  from public.profiles
  where lower(login) = lower(trim(p_login))
  limit 1;

  if target_id is null then
    raise exception 'User not found';
  end if;

  perform public.remove_conversation_member(p_conversation_id, target_id);
end;
$$;

grant execute on function public.add_conversation_member(uuid, uuid) to authenticated;
grant execute on function public.add_conversation_member_by_login(uuid, text) to authenticated;
grant execute on function public.remove_conversation_member(uuid, uuid) to authenticated;
grant execute on function public.remove_conversation_member_by_login(uuid, text) to authenticated;
