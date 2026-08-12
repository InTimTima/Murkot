-- Features v11: listings board ("looking for a team" / "looking for teammates").
-- Users publish ads, others filter them by type and tech stack and respond
-- in a direct chat. Apply in Supabase SQL editor after features_v10.

create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id) on delete cascade,
  type text not null
    check (type in ('looking_for_team', 'looking_for_members')),
  title text not null check (char_length(title) between 3 and 120),
  description text not null default '' check (char_length(description) <= 2000),
  skills text[] not null default '{}',
  compensation text
    check (compensation in ('paid', 'equity', 'pet_project')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.listings enable row level security;

drop policy if exists "Listings are viewable by authenticated users" on public.listings;
create policy "Listings are viewable by authenticated users"
  on public.listings for select to authenticated using (true);

drop policy if exists "Users can insert own listings" on public.listings;
create policy "Users can insert own listings"
  on public.listings for insert to authenticated
  with check (auth.uid() = author_id);

drop policy if exists "Users can update own listings" on public.listings;
create policy "Users can update own listings"
  on public.listings for update to authenticated
  using (auth.uid() = author_id) with check (auth.uid() = author_id);

drop policy if exists "Users can delete own listings" on public.listings;
create policy "Users can delete own listings"
  on public.listings for delete to authenticated
  using (auth.uid() = author_id);

-- Feed is sorted by freshness; filters use type and the skills array.
create index if not exists listings_created_at_idx
  on public.listings (created_at desc);

create index if not exists listings_type_idx
  on public.listings (type)
  where is_active;

create index if not exists listings_skills_gin_idx
  on public.listings using gin (skills);

create index if not exists listings_author_idx
  on public.listings (author_id);
