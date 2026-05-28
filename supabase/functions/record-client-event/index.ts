import 'jsr:@supabase/functions-js/edge-runtime.d.ts';

import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { verifyWalletSignature } from '../_shared/signatures.ts';
import { createAdminClient } from '../_shared/supabase-admin.ts';

type ClientEventPayload = {
  walletAddress: string;
  eventId: string;
  eventType: string;
  category: 'trade' | 'alert' | 'risk' | 'system' | 'marketing' | 'intelligence';
  title: string;
  body: string;
  symbol?: string | null;
  channels?: string[];
  payload?: Record<string, unknown>;
  timestampMs: number;
  message: string;
  signatureBase64: string;
};

function sanitizeSignedField(value: string | null | undefined) {
  return value?.replaceAll('\n', ' ').trim() ?? '';
}

function normalizeChannels(channels: string[] | undefined) {
  return [
    ...new Set(
      (channels ?? ['push', 'email'])
        .map((channel) => channel.trim().toLowerCase())
        .filter((channel) => channel === 'push' || channel === 'email'),
    ),
  ].sort();
}

function buildExpectedMessage(payload: ClientEventPayload) {
  return [
    'dream-notify/record-event',
    `wallet:${payload.walletAddress}`,
    `eventId:${payload.eventId}`,
    `eventType:${payload.eventType}`,
    `category:${payload.category}`,
    `symbol:${sanitizeSignedField(payload.symbol)}`,
    `title:${sanitizeSignedField(payload.title)}`,
    `body:${sanitizeSignedField(payload.body)}`,
    `channels:${normalizeChannels(payload.channels).join(',')}`,
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
    const payload = (await req.json()) as ClientEventPayload;

    if (
      !payload.walletAddress ||
      !payload.eventId ||
      !payload.eventType ||
      !payload.category ||
      !payload.title ||
      !payload.body ||
      !payload.signatureBase64 ||
      !payload.message
    ) {
      return jsonResponse({ error: 'Missing required fields' }, { status: 400 });
    }

    const requestAgeMs = Math.abs(Date.now() - payload.timestampMs);
    if (requestAgeMs > 10 * 60 * 1000) {
      return jsonResponse({ error: 'Expired event request' }, { status: 401 });
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
    const { data: preference, error: preferenceError } = await supabase
      .from('notification_preferences')
      .select('email_address')
      .eq('wallet_address', payload.walletAddress)
      .maybeSingle();
    if (preferenceError) throw preferenceError;

    const eventRow = {
      source: 'client',
      source_event_id: payload.eventId,
      wallet_address: payload.walletAddress,
      email_address: preference?.email_address ?? null,
      event_type: payload.eventType,
      category: payload.category,
      title: payload.title,
      body: payload.body,
      symbol: payload.symbol ?? null,
      channels: normalizeChannels(payload.channels),
      payload: payload.payload ?? {},
    };

    const { error: eventError } = await supabase
      .from('notification_events')
      .upsert(eventRow, { onConflict: 'source,source_event_id' });
    if (eventError) throw eventError;

    return jsonResponse({ success: true });
  } catch (error) {
    console.error('record-client-event failed', error);
    return jsonResponse(
      { error: error instanceof Error ? error.message : 'Unknown error' },
      { status: 500 },
    );
  }
});