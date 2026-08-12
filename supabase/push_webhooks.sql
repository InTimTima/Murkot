-- Wire push Edge Functions via pg_net (same payload shape as Database Webhooks).
-- Safe to re-run. Requires extension pg_net (features_v7).

create extension if not exists pg_net with schema extensions;

create or replace function public.trigger_push_on_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(NEW.is_deleted_for_all, false) then
    return NEW;
  end if;

  perform net.http_post(
    url := 'https://zjozceddfueowkaokpok.supabase.co/functions/v1/push-on-message',
    headers := jsonb_build_object(
      'Content-Type', 'application/json'
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

create or replace function public.trigger_push_on_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform net.http_post(
    url := 'https://zjozceddfueowkaokpok.supabase.co/functions/v1/push-on-event',
    headers := jsonb_build_object(
      'Content-Type', 'application/json'
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

drop trigger if exists push_events_push_webhook on public.push_events;
create trigger push_events_push_webhook
  after insert on public.push_events
  for each row
  execute function public.trigger_push_on_event();
