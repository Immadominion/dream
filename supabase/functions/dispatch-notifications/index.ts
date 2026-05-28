import 'jsr:@supabase/functions-js/edge-runtime.d.ts';

import { JWT } from 'npm:google-auth-library@9.15.1';

import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { createAdminClient } from '../_shared/supabase-admin.ts';

type NotificationEventRow = {
  id: string;
  wallet_address: string;
  email_address: string | null;
  event_type: string;
  title: string;
  body: string;
  symbol: string | null;
  channels: string[];
  category: 'trade' | 'alert' | 'risk' | 'system' | 'marketing' | 'intelligence';
  payload: Record<string, unknown>;
};

type NotificationDeviceRow = {
  wallet_address: string;
  fcm_token: string;
  push_enabled: boolean;
};

type NotificationPreferenceRow = {
  wallet_address: string;
  push_enabled: boolean;
  email_enabled: boolean;
  wallet_activity_enabled: boolean;
  trade_activity_enabled: boolean;
  price_alert_enabled: boolean;
  marketing_enabled: boolean;
};

function isCategoryEnabled(
  preference: NotificationPreferenceRow | null,
  event: NotificationEventRow,
) {
  if (!preference) return true;

  switch (event.category) {
    case 'trade':
    case 'risk':
      return preference.trade_activity_enabled;
    case 'alert':
      return preference.price_alert_enabled;
    case 'marketing':
      return preference.marketing_enabled;
    case 'system':
      return preference.wallet_activity_enabled;
    case 'intelligence':
      return true;
  }
}

function shouldSendEmail(event: NotificationEventRow) {
  return [
    'account_created',
    'wallet_usdc_received',
    'wallet_usdc_sent',
    'position_liquidation_risk',
  ].includes(event.event_type);
}

async function getFcmAccessToken() {
  const rawServiceAccount = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
  if (!rawServiceAccount) return null;

  const credentials = JSON.parse(rawServiceAccount) as {
    client_email: string;
    private_key: string;
  };

  const client = new JWT({
    email: credentials.client_email,
    key: credentials.private_key,
    scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
  });
  const token = await client.authorize();
  return token.access_token ?? null;
}

async function sendPush(
  accessToken: string,
  event: NotificationEventRow,
  device: NotificationDeviceRow,
) {
  const rawServiceAccount = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
  if (!rawServiceAccount) {
    throw new Error('Missing FIREBASE_SERVICE_ACCOUNT_JSON');
  }

  const serviceAccount = JSON.parse(rawServiceAccount) as { project_id: string };
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: device.fcm_token,
          notification: {
            title: event.title,
            body: event.body,
          },
          data: {
            category: event.category,
            route: event.symbol ? 'trade' : 'notifications',
            symbol: event.symbol ?? '',
            event_id: event.id,
          },
        },
      }),
    },
  );

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`FCM send failed: ${JSON.stringify(payload)}`);
  }

  return payload as { name?: string };
}

async function sendEmail(event: NotificationEventRow) {
  const apiKey = Deno.env.get('RESEND_API_KEY');
  const from = Deno.env.get('RESEND_FROM_EMAIL');
  if (!apiKey || !from || !event.email_address) {
    return { skipped: true };
  }

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from,
      to: [event.email_address],
      subject: event.title,
      text: event.body,
    }),
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`Resend send failed: ${JSON.stringify(payload)}`);
  }

  return payload as { id?: string };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const dispatchSecret = Deno.env.get('NOTIFICATION_DISPATCH_SECRET');
  if (dispatchSecret) {
    const provided = req.headers.get('x-webhook-secret');
    if (provided !== dispatchSecret) {
      return jsonResponse({ error: 'Unauthorized' }, { status: 401 });
    }
  }

  try {
    const supabase = createAdminClient();
    const { data: events, error: eventError } = await supabase
      .from('notification_events')
      .select('*')
      .eq('delivery_status', 'queued')
      .lte('available_at', new Date().toISOString())
      .limit(25);
    if (eventError) throw eventError;

    const fcmAccessToken = await getFcmAccessToken();
    let delivered = 0;

    for (const event of (events ?? []) as NotificationEventRow[]) {
      const { data: preference, error: preferenceError } = await supabase
        .from('notification_preferences')
        .select(
          'wallet_address, push_enabled, email_enabled, wallet_activity_enabled, trade_activity_enabled, price_alert_enabled, marketing_enabled',
        )
        .eq('wallet_address', event.wallet_address)
        .maybeSingle();
      if (preferenceError) throw preferenceError;

      await supabase
        .from('notification_events')
        .update({ delivery_status: 'processing' })
        .eq('id', event.id);

      let successCount = 0;
      let skippedCount = 0;
      const categoryEnabled = isCategoryEnabled(
        (preference ?? null) as NotificationPreferenceRow | null,
        event,
      );

      if (!categoryEnabled) {
        skippedCount += event.channels.length;
      }

      if (
        categoryEnabled &&
        event.channels.includes('push') &&
        (preference?.push_enabled ?? true)
      ) {
        const { data: devices, error: deviceError } = await supabase
          .from('notification_devices')
          .select('wallet_address, fcm_token, push_enabled')
          .eq('wallet_address', event.wallet_address)
          .eq('push_enabled', true);
        if (deviceError) throw deviceError;

        for (const device of (devices ?? []) as NotificationDeviceRow[]) {
          try {
            if (!fcmAccessToken) {
              skippedCount += 1;
              await supabase.from('notification_deliveries').upsert({
                event_id: event.id,
                channel: 'push',
                destination: device.fcm_token,
                provider: 'fcm',
                status: 'skipped',
                attempts: 0,
                error_text: 'Missing FIREBASE_SERVICE_ACCOUNT_JSON',
              }, { onConflict: 'event_id,channel,destination' });
              continue;
            }

            const payload = await sendPush(fcmAccessToken, event, device);
            successCount += 1;
            delivered += 1;

            await supabase.from('notification_deliveries').upsert({
              event_id: event.id,
              channel: 'push',
              destination: device.fcm_token,
              provider: 'fcm',
              status: 'sent',
              attempts: 1,
              provider_message_id: payload.name ?? null,
              response_payload: payload,
            }, { onConflict: 'event_id,channel,destination' });
          } catch (error) {
            await supabase.from('notification_deliveries').upsert({
              event_id: event.id,
              channel: 'push',
              destination: device.fcm_token,
              provider: 'fcm',
              status: 'failed',
              attempts: 1,
              error_text: error instanceof Error ? error.message : 'Push failed',
            }, { onConflict: 'event_id,channel,destination' });
          }
        }
      } else if (event.channels.includes('push')) {
        skippedCount += 1;
      }

      if (
        categoryEnabled &&
        event.channels.includes('email') &&
        (preference?.email_enabled ?? false) &&
        shouldSendEmail(event)
      ) {
        try {
          const payload = await sendEmail(event);
          if ('skipped' in payload) {
            skippedCount += 1;
            await supabase.from('notification_deliveries').upsert({
              event_id: event.id,
              channel: 'email',
              destination: event.email_address ?? 'missing-email',
              provider: 'resend',
              status: 'skipped',
              attempts: 0,
              error_text: 'Missing RESEND_API_KEY, RESEND_FROM_EMAIL, or email address',
            }, { onConflict: 'event_id,channel,destination' });
          } else {
            successCount += 1;
            delivered += 1;
            await supabase.from('notification_deliveries').upsert({
              event_id: event.id,
              channel: 'email',
              destination: event.email_address,
              provider: 'resend',
              status: 'sent',
              attempts: 1,
              provider_message_id: payload.id ?? null,
              response_payload: payload,
            }, { onConflict: 'event_id,channel,destination' });
          }
        } catch (error) {
          await supabase.from('notification_deliveries').upsert({
            event_id: event.id,
            channel: 'email',
            destination: event.email_address ?? 'missing-email',
            provider: 'resend',
            status: 'failed',
            attempts: 1,
            error_text: error instanceof Error ? error.message : 'Email failed',
          }, { onConflict: 'event_id,channel,destination' });
        }
      } else if (event.channels.includes('email')) {
        skippedCount += 1;
        await supabase.from('notification_deliveries').upsert({
          event_id: event.id,
          channel: 'email',
          destination: event.email_address ?? 'missing-email',
          provider: 'resend',
          status: 'skipped',
          attempts: 0,
          error_text: !categoryEnabled
            ? 'Notification category disabled by user preference'
            : !(preference?.email_enabled ?? false)
            ? 'Email notifications disabled by user preference'
            : 'Email suppressed for this event type',
        }, { onConflict: 'event_id,channel,destination' });
      }

      const nextStatus = successCount > 0
        ? 'sent'
        : skippedCount > 0
        ? 'skipped'
        : 'failed';

      await supabase
        .from('notification_events')
        .update({
          delivery_status: nextStatus,
          processed_at: new Date().toISOString(),
        })
        .eq('id', event.id);
    }

    return jsonResponse({ success: true, delivered });
  } catch (error) {
    console.error('dispatch-notifications failed', error);
    return jsonResponse(
      { error: error instanceof Error ? error.message : 'Unknown error' },
      { status: 500 },
    );
  }
});