-- Features v10: developer card on profiles.
-- Adds job-search status, tech stack, experience level, links and city
-- for the "find a team / find teammates" platform features.
-- Apply in Supabase SQL editor after features_v9.

alter table public.profiles
  add column if not exists dev_status text not null default 'none'
    check (dev_status in ('none', 'looking_for_team', 'looking_for_members', 'open_to_offers')),
  add column if not exists skills text[] not null default '{}',
  add column if not exists experience_level text
    check (experience_level in ('junior', 'middle', 'senior', 'lead')),
  add column if not exists github_url text,
  add column if not exists portfolio_url text,
  add column if not exists city text;

-- Fast lookup of people by technology for the future listings/matching search.
create index if not exists profiles_skills_gin_idx
  on public.profiles using gin (skills);

create index if not exists profiles_dev_status_idx
  on public.profiles (dev_status)
  where dev_status <> 'none';
