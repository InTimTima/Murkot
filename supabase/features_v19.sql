-- Features v19: listing responses as first-class entities
-- Apply after features_v17/v18.

create table if not exists public.listing_responses (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings (id) on delete cascade,
  responder_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'in_chat'
    check (status in ('pending', 'in_chat', 'accepted', 'rejected', 'withdrawn')),
  conversation_id uuid references public.conversations (id) on delete set null,
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint listing_responses_unique unique (listing_id, responder_id)
);

create index if not exists listing_responses_listing_idx
  on public.listing_responses (listing_id, created_at desc);

create index if not exists listing_responses_responder_idx
  on public.listing_responses (responder_id, created_at desc);

alter table public.listing_responses enable row level security;

drop policy if exists "Responders and authors can view responses" on public.listing_responses;
create policy "Responders and authors can view responses"
  on public.listing_responses for select to authenticated
  using (
    auth.uid() = responder_id
    or exists (
      select 1 from public.listings l
      where l.id = listing_id and l.author_id = auth.uid()
    )
  );

drop policy if exists "Users insert own responses" on public.listing_responses;
create policy "Users insert own responses"
  on public.listing_responses for insert to authenticated
  with check (auth.uid() = responder_id);

drop policy if exists "Responders and authors update responses" on public.listing_responses;
create policy "Responders and authors update responses"
  on public.listing_responses for update to authenticated
  using (
    auth.uid() = responder_id
    or exists (
      select 1 from public.listings l
      where l.id = listing_id and l.author_id = auth.uid()
    )
  )
  with check (
    auth.uid() = responder_id
    or exists (
      select 1 from public.listings l
      where l.id = listing_id and l.author_id = auth.uid()
    )
  );

grant select, insert, update on table public.listing_responses to authenticated;

-- Create / refresh a response when user responds to a listing.
create or replace function public.respond_to_listing(
  p_listing_id uuid,
  p_conversation_id uuid default null,
  p_note text default ''
)
returns public.listing_responses
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  listing_author uuid;
  row public.listing_responses;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  select author_id into listing_author
  from public.listings
  where id = p_listing_id and is_active = true;

  if listing_author is null then
    raise exception 'Listing not found';
  end if;
  if listing_author = uid then
    raise exception 'Cannot respond to own listing';
  end if;

  insert into public.listing_responses (
    listing_id, responder_id, status, conversation_id, note, updated_at
  )
  values (
    p_listing_id,
    uid,
    'in_chat',
    p_conversation_id,
    left(coalesce(p_note, ''), 500),
    now()
  )
  on conflict (listing_id, responder_id) do update
    set status = 'in_chat',
        conversation_id = coalesce(excluded.conversation_id, public.listing_responses.conversation_id),
        note = case
          when excluded.note = '' then public.listing_responses.note
          else excluded.note
        end,
        updated_at = now()
  returning * into row;

  return row;
end;
$$;

grant execute on function public.respond_to_listing(uuid, uuid, text) to authenticated;

-- Author updates response status (accepted / rejected) or responder withdraws.
create or replace function public.set_listing_response_status(
  p_response_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  r public.listing_responses;
  listing_author uuid;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_status not in ('pending', 'in_chat', 'accepted', 'rejected', 'withdrawn') then
    raise exception 'Invalid status';
  end if;

  select * into r from public.listing_responses where id = p_response_id;
  if r.id is null then
    raise exception 'Response not found';
  end if;

  select author_id into listing_author from public.listings where id = r.listing_id;

  if p_status = 'withdrawn' then
    if uid <> r.responder_id then
      raise exception 'Only responder can withdraw';
    end if;
  else
    if uid <> listing_author and uid <> r.responder_id then
      raise exception 'Not allowed';
    end if;
    -- Only author may accept/reject
    if p_status in ('accepted', 'rejected') and uid <> listing_author then
      raise exception 'Only author can accept or reject';
    end if;
  end if;

  update public.listing_responses
  set status = p_status, updated_at = now()
  where id = p_response_id;
end;
$$;

grant execute on function public.set_listing_response_status(uuid, text) to authenticated;
