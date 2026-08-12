-- Real push: Database Webhook → Edge Function push-on-message
-- Run after features_v6.sql (device_tokens).
--
-- 1) Generate VAPID keys (do not commit the private key):
--    npx web-push generate-vapid-keys
--    Put PUBLIC key in lib/config/push_config.dart
--    Put BOTH keys as Supabase secrets (see README Push section)
--
-- 2) Deploy:
--    npx supabase login
--    npx supabase link --project-ref zjozceddfueowkaokpok
--    npx supabase secrets set VAPID_PUBLIC_KEY="<public>"
--    npx supabase secrets set VAPID_PRIVATE_KEY="<private>"
--    npx supabase secrets set VAPID_SUBJECT="mailto:support@murkot.app"
--    npx supabase functions deploy push-on-message --no-verify-jwt
--    npx supabase functions deploy push-on-event --no-verify-jwt
--
-- 3) Database Webhooks (Dashboard → Database → Webhooks):
--    A) Name: push-on-message
--       Table: public.messages | Events: INSERT
--       Type: Supabase Edge Functions | Function: push-on-message
--    B) Name: push-on-event
--       Table: public.push_events | Events: INSERT
--       Type: Supabase Edge Functions | Function: push-on-event
--
-- Optional SQL fallback (replace SERVICE_ROLE_JWT). Prefer Dashboard webhook.

create extension if not exists pg_net with schema extensions;

-- Helper: call only if you prefer SQL over Dashboard webhook.
-- Leave commented until SERVICE_ROLE_JWT is filled in.
/*
create or replace function public.trigger_push_on_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform net.http_post(
    url := 'https://zjozceddfueowkaokpok.supabase.co/functions/v1/push-on-message',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer SERVICE_ROLE_JWT'
    ),
    body := jsonb_build_object(
      'type', TG_OP,
      'table', TG_TABLE_NAME,
      'schema', TG_TABLE_SCHEMA,
      'record', to_jsonb(NEW),
      'old_record', null
    )
  );
  return NEW;
end;
$$;

drop trigger if exists messages_push_webhook on public.messages;
create trigger messages_push_webhook
  after insert on public.messages
  for each row
  execute function public.trigger_push_on_message();
*/

-- Ensure service role can read tokens (bypasses RLS anyway via service key).
-- No schema change required beyond features_v6 device_tokens.
select 1;
