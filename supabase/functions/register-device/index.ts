import 'jsr:@supabase/functions-js/edge-runtime.d.ts';

import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { verifyWalletSignature } from '../_shared/signatures.ts';
import { createAdminClient } from '../_shared/supabase-admin.ts';

type RegisterDevicePayload = {
  walletAddress: string;
  email?: string | null;
  deviceToken: string;
  installationId: string;
  platform: 'android' | 'ios' | 'unknown';
  appVersion?: string | null;
  locale?: string | null;
  timestampMs: number;
  message: string;
  signatureBase64: string;
};

function buildExpectedMessage(payload: RegisterDevicePayload) {
  return [
    'dream-notify/register-device',
    `wallet:${payload.walletAddress}`,
    `token:${payload.deviceToken}`,
    `installation:${payload.installationId}`,
    `platform:${payload.platform}`,
    `appVersion:${payload.appVersion ?? '1.0.0'}`,
    `locale:${payload.locale ?? ''}`,
    `email:${payload.email ?? ''}`,
    `timestampMs:${payload.timestampMs}`,
  ].join('\n');
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, { status: 405 });
  }

  try {
    const payload = (await req.json()) as RegisterDevicePayload;

    if (
      !payload.walletAddress ||
      !payload.deviceToken ||
      !payload.installationId ||
      !payload.signatureBase64 ||
      !payload.message
    ) {
      return jsonResponse({ error: 'Missing required fields' }, { status: 400 });
    }

    const requestAgeMs = Math.abs(Date.now() - payload.timestampMs);
    if (requestAgeMs > 10 * 60 * 1000) {
      return jsonResponse({ error: 'Expired registration request' }, { status: 401 });
    }

    const expectedMessage = buildExpectedMessage(payload);
    if (expectedMessage !== payload.message) {
      return jsonResponse({ error: 'Signed message mismatch' }, { status: 400 });
    }

    const isValid = verifyWalletSignature(
      payload.walletAddress,
      payload.message,
      payload.signatureBase64,
    );
    if (!isValid) {
      return jsonResponse({ error: 'Invalid wallet signature' }, { status: 401 });
    }

    const supabase = createAdminClient();
    const { data: existingPreference, error: existingPreferenceError } = await supabase
      .from('notification_preferences')
      .select('wallet_address')
      .eq('wallet_address', payload.walletAddress)
      .maybeSingle();
    if (existingPreferenceError) throw existingPreferenceError;

    const isFirstWalletRegistration = existingPreference == null;

    const deviceRow = {
      installation_id: payload.installationId,
      wallet_address: payload.walletAddress,
      email_address: payload.email ?? null,
      platform: payload.platform,
      fcm_token: payload.deviceToken,
      app_version: payload.appVersion ?? null,
      locale: payload.locale ?? null,
      push_enabled: true,
      last_seen_at: new Date(payload.timestampMs).toISOString(),
    };

    const { error: deviceError } = await supabase
      .from('notification_devices')
      .upsert(deviceRow, { onConflict: 'installation_id' });
    if (deviceError) throw deviceError;

    const { error: prefError } = await supabase
      .from('notification_preferences')
      .upsert(
        {
          wallet_address: payload.walletAddress,
          email_address: payload.email ?? null,
          push_enabled: true,
        },
        { onConflict: 'wallet_address' },
      );
    if (prefError) throw prefError;

    if (isFirstWalletRegistration) {
      const { error: welcomeError } = await supabase
        .from('notification_events')
        .upsert(
          {
            source: 'client',
            source_event_id: `welcome:${payload.walletAddress}`,
            wallet_address: payload.walletAddress,
            email_address: payload.email ?? null,
            event_type: 'account_created',
            category: 'system',
            title: 'Notifications ready',
            body:
                'Your Dream account is connected on this device. You will now receive wallet, trade, and risk alerts.',
            symbol: null,
            channels: ['push'],
            payload: {
              walletAddress: payload.walletAddress,
              installationId: payload.installationId,
              trigger: 'register_device',
            },
          },
          { onConflict: 'source,source_event_id' },
        );
      if (welcomeError) throw welcomeError;
    }

    return jsonResponse({ success: true });
  } catch (error) {
    console.error('register-device failed', error);
    return jsonResponse(
      { error: error instanceof Error ? error.message : 'Unknown error' },
      { status: 500 },
    );
  }
});