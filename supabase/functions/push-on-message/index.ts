// Deno Edge Function: send Web Push (and optional FCM) on new messages.
// Deploy: npx supabase functions deploy push-on-message --no-verify-jwt
// Secrets:
//   VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT
//   Optional: FCM_SERVER_KEY (legacy HTTP)
// Trigger via Database Webhook on public.messages INSERT (see features_v7.sql).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'
import webpush from 'npm:web-push@3.6.7'

type WebhookPayload = {
  type: string
  table: string
  record: {
    id: string
    conversation_id: string
    sender_id: string
    type: string
    content: string
    is_deleted_for_all?: boolean
  }
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

function previewBody(type: string, content: string): string {
  if (type === 'text') {
    return content.length > 140 ? `${content.slice(0, 137)}...` : content
  }
  try {
    const parsed = JSON.parse(content)
    if (parsed?.name) return String(parsed.name)
  } catch (_) {
    // ignore
  }
  return type || 'сообщение'
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const payload = (await req.json()) as WebhookPayload
    const record = payload.record
    if (!record?.conversation_id || !record?.sender_id) {
      return new Response(JSON.stringify({ ok: true, skipped: 'no record' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    if (record.is_deleted_for_all) {
      return new Response(JSON.stringify({ ok: true, skipped: 'deleted' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const admin = createClient(supabaseUrl, serviceKey)

    const vapidPublic = Deno.env.get('VAPID_PUBLIC_KEY')
    const vapidPrivate = Deno.env.get('VAPID_PRIVATE_KEY')
    const vapidSubject = Deno.env.get('VAPID_SUBJECT') ?? 'mailto:support@tujh.app'
    if (vapidPublic && vapidPrivate) {
      webpush.setVapidDetails(vapidSubject, vapidPublic, vapidPrivate)
    }

    const [{ data: members }, { data: conversation }, { data: sender }] =
      await Promise.all([
        admin
          .from('conversation_members')
          .select('user_id')
          .eq('conversation_id', record.conversation_id),
        admin
          .from('conversations')
          .select('id, name, type')
          .eq('id', record.conversation_id)
          .maybeSingle(),
        admin
          .from('profiles')
          .select('id, login')
          .eq('id', record.sender_id)
          .maybeSingle(),
      ])

    const recipientIds = (members ?? [])
      .map((m) => m.user_id as string)
      .filter((id) => id !== record.sender_id)

    if (recipientIds.length === 0) {
      return new Response(JSON.stringify({ ok: true, sent: 0 }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { data: tokens } = await admin
      .from('device_tokens')
      .select('id, token, platform, user_id')
      .in('user_id', recipientIds)

    const title =
      conversation?.name?.trim() ||
      sender?.login ||
      'Tujh'
    const body = `${sender?.login ?? 'Кто-то'}: ${previewBody(
      record.type,
      record.content,
    )}`
    const pushPayload = JSON.stringify({
      title,
      body,
      conversationId: record.conversation_id,
      messageId: record.id,
    })

    let sent = 0
    const staleTokenIds: string[] = []
    const fcmKey = Deno.env.get('FCM_SERVER_KEY')

    for (const row of tokens ?? []) {
      const token = row.token as string
      try {
        if (token.trim().startsWith('{')) {
          if (!vapidPublic || !vapidPrivate) continue
          const subscription = JSON.parse(token)
          await webpush.sendNotification(subscription, pushPayload)
          sent++
        } else if (fcmKey && row.platform !== 'web') {
          const res = await fetch('https://fcm.googleapis.com/fcm/send', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `key=${fcmKey}`,
            },
            body: JSON.stringify({
              to: token,
              notification: { title, body },
              data: {
                conversationId: record.conversation_id,
                messageId: record.id,
              },
            }),
          })
          if (res.ok) sent++
          else if (res.status === 404 || res.status === 410) {
            staleTokenIds.push(row.id as string)
          }
        }
      } catch (err) {
        const status = (err as { statusCode?: number })?.statusCode
        if (status === 404 || status === 410) {
          staleTokenIds.push(row.id as string)
        } else {
          console.error('push failed', row.id, err)
        }
      }
    }

    if (staleTokenIds.length > 0) {
      await admin.from('device_tokens').delete().in('id', staleTokenIds)
    }

    return new Response(JSON.stringify({ ok: true, sent }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    console.error(error)
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
