import 'jsr:@supabase/functions-js/edge-runtime.d.ts';

import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { createAdminClient } from '../_shared/supabase-admin.ts';

const USDC_MINT = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';

type NotificationPreference = {
  wallet_address: string;
  email_address: string | null;
};

type NormalizedEvent = {
  source: string;
  source_event_id: string;
  wallet_address: string;
  email_address: string | null;
  event_type: string;
  category: 'trade' | 'alert' | 'risk' | 'system' | 'marketing' | 'intelligence';
  title: string;
  body: string;
  symbol: string | null;
  channels: string[];
  payload: Record<string, unknown>;
};

function getWebhookSecret(req: Request) {
  const url = new URL(req.url);
  return (
    req.headers.get('authorization') ??
    req.headers.get('x-webhook-secret') ??
    url.searchParams.get('secret')
  );
}

function matchesWebhookSecret(provided: string | null, expected: string) {
  if (!provided) return false;
  if (provided === expected) return true;

  const providedBearer = provided.startsWith('Bearer ')
    ? provided.slice('Bearer '.length)
    : provided;
  const expectedBearer = expected.startsWith('Bearer ')
    ? expected.slice('Bearer '.length)
    : expected;

  return providedBearer === expectedBearer;
}

function findWatchedWallets(
  tx: Record<string, unknown>,
  watched: Map<string, NotificationPreference>,
) {
  const related = new Set<string>();

  const accountData = Array.isArray(tx.accountData) ? tx.accountData : [];
  for (const account of accountData) {
    const accountAddress =
      typeof account === 'object' && account !== null
        ? String((account as Record<string, unknown>).account ?? '')
        : '';
    if (watched.has(accountAddress)) related.add(accountAddress);
  }

  const tokenTransfers = Array.isArray(tx.tokenTransfers) ? tx.tokenTransfers : [];
  for (const transfer of tokenTransfers) {
    if (typeof transfer !== 'object' || transfer === null) continue;
    const row = transfer as Record<string, unknown>;
    for (const key of ['fromUserAccount', 'toUserAccount', 'fromOwner', 'toOwner']) {
      const address = typeof row[key] === 'string' ? String(row[key]) : '';
      if (watched.has(address)) related.add(address);
    }
  }

  const nativeTransfers = Array.isArray(tx.nativeTransfers) ? tx.nativeTransfers : [];
  for (const transfer of nativeTransfers) {
    if (typeof transfer !== 'object' || transfer === null) continue;
    const row = transfer as Record<string, unknown>;
    for (const key of ['fromUserAccount', 'toUserAccount']) {
      const address = typeof row[key] === 'string' ? String(row[key]) : '';
      if (watched.has(address)) related.add(address);
    }
  }

  return [...related];
}

function tokenAmountUi(value: unknown) {
  if (typeof value === 'number') return value;
  if (typeof value === 'string') return Number(value) || 0;
  if (typeof value === 'object' && value !== null) {
    const row = value as Record<string, unknown>;
    if (typeof row.tokenAmount === 'number') return row.tokenAmount;
    if (typeof row.uiAmount === 'number') return row.uiAmount;
    if (typeof row.uiTokenAmount === 'number') return row.uiTokenAmount;
    if (typeof row.amount === 'number' && typeof row.decimals === 'number') {
      return row.amount / 10 ** row.decimals;
    }
  }
  return 0;
}

function normalizeEvents(
  tx: Record<string, unknown>,
  watched: Map<string, NotificationPreference>,
) {
  const signature = String(tx.signature ?? tx.transactionSignature ?? crypto.randomUUID());
  const tokenTransfers = Array.isArray(tx.tokenTransfers) ? tx.tokenTransfers : [];
  const events: NormalizedEvent[] = [];

  for (const transfer of tokenTransfers) {
    if (typeof transfer !== 'object' || transfer === null) continue;
    const row = transfer as Record<string, unknown>;
    const mint = String(row.mint ?? '');
    const amount = tokenAmountUi(row.tokenAmount ?? row.amount);
    const fromWallet = String(
      row.fromUserAccount ?? row.fromOwner ?? row.fromAddress ?? '',
    );
    const toWallet = String(row.toUserAccount ?? row.toOwner ?? row.toAddress ?? '');

    if (watched.has(toWallet)) {
      const pref = watched.get(toWallet)!;
      const isUsdc = mint === USDC_MINT;
      events.push({
        source: 'helius',
        source_event_id: `${signature}:${toWallet}:token-in:${mint}:${amount}`,
        wallet_address: toWallet,
        email_address: pref.email_address,
        event_type: isUsdc ? 'wallet_usdc_received' : 'wallet_token_received',
        category: 'system',
        title: isUsdc ? 'USDC received' : 'Token received',
        body: isUsdc
            ? `${amount.toFixed(2)} USDC arrived in your Dream wallet.`
            : `Incoming token transfer detected in your Dream wallet.`,
        symbol: null,
        channels: ['push', 'email'],
        payload: tx,
      });
    }

    if (watched.has(fromWallet)) {
      const pref = watched.get(fromWallet)!;
      const isUsdc = mint === USDC_MINT;
      events.push({
        source: 'helius',
        source_event_id: `${signature}:${fromWallet}:token-out:${mint}:${amount}`,
        wallet_address: fromWallet,
        email_address: pref.email_address,
        event_type: isUsdc ? 'wallet_usdc_sent' : 'wallet_token_sent',
        category: 'system',
        title: isUsdc ? 'USDC sent' : 'Token sent',
        body: isUsdc
            ? `${amount.toFixed(2)} USDC left your Dream wallet.`
            : `Outgoing token transfer detected in your Dream wallet.`,
        symbol: null,
        channels: ['push'],
        payload: tx,
      });
    }
  }

  if (events.length > 0) return events;

  const relatedWallets = findWatchedWallets(tx, watched);
  const txType = String(tx.type ?? 'ACTIVITY').toLowerCase();
  for (const walletAddress of relatedWallets) {
    const pref = watched.get(walletAddress)!;
    events.push({
      source: 'helius',
      source_event_id: `${signature}:${walletAddress}:generic:${txType}`,
      wallet_address: walletAddress,
      email_address: pref.email_address,
      event_type: `wallet_${txType}`,
      category: 'system',
      title: 'Wallet activity confirmed',
      body: `A ${txType.replaceAll('_', ' ')} transaction was confirmed for your Dream wallet.`,
      symbol: null,
      channels: ['push'],
      payload: tx,
    });
  }

  return events;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const expectedSecret = Deno.env.get('HELIUS_WEBHOOK_SECRET');
  if (!expectedSecret || !matchesWebhookSecret(getWebhookSecret(req), expectedSecret)) {
    return jsonResponse({ error: 'Unauthorized' }, { status: 401 });
  }

  try {
    const rawPayload = await req.json();
    const payloads = Array.isArray(rawPayload) ? rawPayload : [rawPayload];
    const supabase = createAdminClient();

    const { data: preferences, error: prefError } = await supabase
      .from('notification_preferences')
      .select('wallet_address, email_address');
    if (prefError) throw prefError;

    const watched = new Map<string, NotificationPreference>();
    for (const preference of preferences ?? []) {
      watched.set(preference.wallet_address, preference);
    }

    const events = payloads.flatMap((item) =>
      typeof item === 'object' && item !== null
        ? normalizeEvents(item as Record<string, unknown>, watched)
        : [],
    );

    const { error: ingestError } = await supabase
      .from('notification_webhook_ingest')
      .insert({
        source: 'helius',
        request_path: new URL(req.url).pathname,
        request_headers: Object.fromEntries(req.headers.entries()),
        payload: rawPayload,
        processed_count: events.length,
      });
    if (ingestError) throw ingestError;

    if (events.length > 0) {
      const { error: eventError } = await supabase
        .from('notification_events')
        .upsert(events, {
          onConflict: 'source,source_event_id',
          ignoreDuplicates: true,
        });
      if (eventError) throw eventError;
    }

    return jsonResponse({ success: true, processed: events.length });
  } catch (error) {
    console.error('helius-webhook failed', error);
    return jsonResponse(
      { error: error instanceof Error ? error.message : 'Unknown error' },
      { status: 500 },
    );
  }
});