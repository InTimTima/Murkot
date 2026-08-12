-- Hotfix: restore profiles table grants after a partial v16 apply.
-- Paste in Supabase SQL Editor, then re-run seed if needed.

grant select (
  id, login, status, avatar_url, avatar_emoji, profile_wallpaper_id,
  custom_wallpaper_url, birthday, created_at, updated_at,
  last_seen_at, is_bot, dev_status, skills, experience_level,
  github_url, portfolio_url, city
) on table public.profiles to authenticated;

grant update (
  login, status, avatar_url, avatar_emoji, profile_wallpaper_id,
  custom_wallpaper_url, birthday, updated_at,
  dev_status, skills, experience_level, github_url, portfolio_url, city
) on table public.profiles to authenticated;

grant insert (
  id, login, email, status, avatar_url, avatar_emoji, profile_wallpaper_id,
  custom_wallpaper_url, birthday, dev_status, skills, experience_level,
  github_url, portfolio_url, city, is_bot
) on table public.profiles to authenticated;

grant delete on table public.profiles to authenticated;

-- Also ensure listings are writable for seed / app.
grant select, insert, update, delete on table public.listings to authenticated;
