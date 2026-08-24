-- Features v22: guest browse + do-not-disturb status.
-- Apply after features_v21.sql

-- Public read so guests (anon key, no session) can scroll the board.
drop policy if exists "Listings are viewable by authenticated users" on public.listings;
drop policy if exists "Listings are viewable by anyone" on public.listings;
create policy "Listings are viewable by anyone"
  on public.listings for select using (true);

drop policy if exists "Projects are viewable by authenticated users" on public.projects;
drop policy if exists "Projects are viewable by anyone" on public.projects;
create policy "Projects are viewable by anyone"
  on public.projects for select using (true);

grant select on table public.listings to anon;
grant select on table public.projects to anon;

grant select (
  id, login, status, avatar_url, avatar_emoji, profile_wallpaper_id,
  custom_wallpaper_url, birthday, created_at, updated_at,
  last_seen_at, is_bot, dev_status, skills, experience_level,
  github_url, portfolio_url, city
) on table public.profiles to anon;

grant execute on function public.search_people(text, text, text, text, int, int)
  to anon;

-- DND on the developer card.
alter table public.profiles drop constraint if exists profiles_dev_status_check;
alter table public.profiles
  add constraint profiles_dev_status_check
  check (dev_status in (
    'none',
    'looking_for_team',
    'looking_for_members',
    'open_to_offers',
    'do_not_disturb'
  ));
