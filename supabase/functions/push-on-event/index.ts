// Deno Edge Function: send Web Push for generic push_events rows.
// Deploy: npx supabase functions deploy push-on-event --no-verify-jwt
// Secrets: same VAPID_* as push-on-message
// Trigger: Database Webhook on public.push_events INSERT (see features_v17.sql).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'
import webpush from 'npm:web-push@3.6.7'

type WebhookPayload = {
  type: string
  table: string
  record: {
    id: string
    user_id: string
    title: string
    body: string
    data?: Record<string, unknown>
  }
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const payload = (await req.json()) as WebhookPayload
    const record = payload.record
    if (!record?.user_id || !record?.title) {
      return new Response(JSON.stringify({ ok: true, skipped: 'no record' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const admin = createClient(supabaseUrl, serviceKey)

    const vapidPublic = Deno.env.get('VAPID_PUBLIC_KEY')
    const vapidPrivate = Deno.env.get('VAPID_PRIVATE_KEY')
    const vapidSubject =
      Deno.env.get('VAPID_SUBJECT') ?? 'mailto:support@murkot.app'
    if (vapidPublic && vapidPrivate) {
      webpush.setVapidDetails(vapidSubject, vapidPublic, vapidPrivate)
    }

    const { data: tokens } = await admin
      .from('device_tokens')
      .select('id, token, platform, user_id')
      .eq('user_id', record.user_id)

    const title = record.title.trim() || 'Murkot'
    const body = record.body ?? ''
    const pushPayload = JSON.stringify({
      title,
      body,
      ...(record.data ?? {}),
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
              data: record.data ?? {},
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
