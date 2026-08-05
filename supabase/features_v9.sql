-- Features v9: rename the built-in bot from TujhBot to Murkot.
-- Apply in Supabase SQL editor after features_v8.

update public.profiles
set login = 'Murkot'
where id = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeee01';

update auth.users
set raw_user_meta_data = jsonb_set(
  coalesce(raw_user_meta_data, '{}'::jsonb),
  '{login}',
  '"Murkot"'
)
where id = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeee01';
