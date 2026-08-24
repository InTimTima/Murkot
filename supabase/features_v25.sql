-- Features v25: feedback letters, match liked views, project avatar
-- Apply after features_v24.sql

-- 1) Feedback letters -------------------------------------------------
create table if not exists public.feedback_letters (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  author_login text not null,
  text text not null check (char_length(text) between 1 and 2000),
  photo_url text,
  created_at timestamptz not null default now()
);

alter table public.feedback_letters enable row level security;

drop policy if exists "Auth can insert own feedback" on public.feedback_letters;
create policy "Auth can insert own feedback"
  on public.feedback_letters for insert to authenticated
  with check (author_id = auth.uid());

drop policy if exists "Admin can view feedback" on public.feedback_letters;
create policy "Admin can view feedback"
  on public.feedback_letters for select to authenticated
  using (public.is_app_admin());

-- RPC to submit feedback (handles anon key insert via auth)
create or replace function public.submit_feedback(p_text text, p_photo_url text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_login text;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if nullif(trim(p_text), '') is null then raise exception 'Empty text'; end if;
  select login into v_login from public.profiles where id = auth.uid();
  insert into public.feedback_letters (author_id, author_login, text, photo_url)
  values (auth.uid(), coalesce(v_login, 'user'), trim(p_text), nullif(trim(coalesce(p_photo_url,'')), ''))
  returning id into v_id;
  return v_id;
end;
$$;
grant execute on function public.submit_feedback(text, text) to authenticated;

create or replace function public.admin_list_feedback()
returns table (id uuid, author_id uuid, author_login text, text text, photo_url text, created_at timestamptz, avatar_url text, avatar_emoji text)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_app_admin() then raise exception 'Not an admin'; end if;
  return query
  select f.id, f.author_id, f.author_login, f.text, f.photo_url, f.created_at,
         p.avatar_url, p.avatar_emoji
  from public.feedback_letters f
  left join public.profiles p on p.id = f.author_id
  order by f.created_at desc
  limit 100;
end;
$$;
grant execute on function public.admin_list_feedback() to authenticated;

-- 2) Projects avatar + photos -----------------------------------------
alter table public.projects
  add column if not exists avatar_url text,
  add column if not exists image_urls text[] not null default '{}';

-- 3) Match: who liked me / whom I liked -------------------------------
create or replace function public.get_who_liked_me()
returns table (id uuid, login text, status text, avatar_emoji text, avatar_url text, is_bot boolean, dev_status text, skills text[], experience_level text, github_url text, portfolio_url text, city text, shared_skills int)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select p.id, p.login, p.status, p.avatar_emoji, p.avatar_url, coalesce(p.is_bot,false), coalesce(p.dev_status,'none'), coalesce(p.skills,'{}'), p.experience_level, p.github_url, p.portfolio_url, p.city, 0::int
  from public.profiles p
  where p.id in (
    select s.swiper_id from public.match_swipes s where s.target_id = auth.uid() and s.liked = true
  )
  and p.id <> auth.uid()
  and coalesce(p.is_bot,false)=false
  order by p.created_at desc limit 40;
end;
$$;
grant execute on function public.get_who_liked_me() to authenticated;

create or replace function public.get_whom_i_liked()
returns table (id uuid, login text, status text, avatar_emoji text, avatar_url text, is_bot boolean, dev_status text, skills text[], experience_level text, github_url text, portfolio_url text, city text, shared_skills int)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select p.id, p.login, p.status, p.avatar_emoji, p.avatar_url, coalesce(p.is_bot,false), coalesce(p.dev_status,'none'), coalesce(p.skills,'{}'), p.experience_level, p.github_url, p.portfolio_url, p.city, 0::int
  from public.profiles p
  where p.id in (
    select s.target_id from public.match_swipes s where s.swiper_id = auth.uid() and s.liked = true
  )
  and coalesce(p.is_bot,false)=false
  order by p.created_at desc limit 40;
end;
$$;
grant execute on function public.get_whom_i_liked() to authenticated;
