-- Features v9: rename the built-in bot from TujhBot to Murkot.
-- Apply in Supabase SQL editor after features_v8.

-- The app reads the bot name from public.profiles — this is the important part.
update public.profiles
set login = 'Murkot'
where login = 'TujhBot' or id = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeee01';

-- auth.users metadata is cosmetic; skip silently if the SQL editor role
-- has no privileges on the auth schema.
do $$
begin
  update auth.users
  set raw_user_meta_data = jsonb_set(
    coalesce(raw_user_meta_data, '{}'::jsonb),
    '{login}',
    '"Murkot"'
  )
  where id = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeee01';
exception
  when insufficient_privilege then
    raise notice 'auth.users not updated (no privileges) — this is fine.';
end $$;
