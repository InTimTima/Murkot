-- Features v12: project showcase.
-- Users publish their projects (description, stack, demo/repo links and
-- which teammates they still need); others can browse and contact the author.
-- Apply in Supabase SQL editor after features_v11.

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id) on delete cascade,
  name text not null check (char_length(name) between 3 and 80),
  description text not null default '' check (char_length(description) <= 3000),
  stack text[] not null default '{}',
  looking_for text[] not null default '{}',
  demo_url text,
  repo_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.projects enable row level security;

drop policy if exists "Projects are viewable by authenticated users" on public.projects;
create policy "Projects are viewable by authenticated users"
  on public.projects for select to authenticated using (true);

drop policy if exists "Users can insert own projects" on public.projects;
create policy "Users can insert own projects"
  on public.projects for insert to authenticated
  with check (auth.uid() = author_id);

drop policy if exists "Users can update own projects" on public.projects;
create policy "Users can update own projects"
  on public.projects for update to authenticated
  using (auth.uid() = author_id) with check (auth.uid() = author_id);

drop policy if exists "Users can delete own projects" on public.projects;
create policy "Users can delete own projects"
  on public.projects for delete to authenticated
  using (auth.uid() = author_id);

create index if not exists projects_created_at_idx
  on public.projects (created_at desc);

create index if not exists projects_stack_gin_idx
  on public.projects using gin (stack);

create index if not exists projects_author_idx
  on public.projects (author_id);
