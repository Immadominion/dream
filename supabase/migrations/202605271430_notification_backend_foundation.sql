create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.notification_preferences (
  wallet_address text primary key,
  email_address text,
  push_enabled boolean not null default true,
  email_enabled boolean not null default false,
  wallet_activity_enabled boolean not null default true,
  trade_activity_enabled boolean not null default true,
  price_alert_enabled boolean not null default true,
  marketing_enabled boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.notification_devices (
  id uuid primary key default gen_random_uuid(),
  installation_id text not null unique,
  wallet_address text not null,
  email_address text,
  platform text not null check (platform in ('android', 'ios', 'unknown')),
  fcm_token text not null,
  app_version text,
  locale text,
  push_enabled boolean not null default true,
  last_seen_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists notification_devices_wallet_token_idx
  on public.notification_devices (wallet_address, fcm_token);

create index if not exists notification_devices_wallet_address_idx
  on public.notification_devices (wallet_address);

create table if not exists public.notification_events (
  id uuid primary key default gen_random_uuid(),
  source text not null,
  source_event_id text not null,
  wallet_address text not null,
  email_address text,
  event_type text not null,
  category text not null check (category in ('trade', 'alert', 'risk', 'system', 'marketing', 'intelligence')),
  title text not null,
  body text not null,
  symbol text,
  channels text[] not null default array['push']::text[],
  payload jsonb not null default '{}'::jsonb,
  delivery_status text not null default 'queued' check (delivery_status in ('queued', 'processing', 'sent', 'failed', 'skipped')),
  available_at timestamptz not null default timezone('utc', now()),
  processed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (source, source_event_id)
);

create index if not exists notification_events_wallet_address_idx
  on public.notification_events (wallet_address, created_at desc);

create index if not exists notification_events_delivery_status_idx
  on public.notification_events (delivery_status, available_at);

create table if not exists public.notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.notification_events (id) on delete cascade,
  channel text not null check (channel in ('push', 'email')),
  destination text not null,
  provider text not null,
  status text not null check (status in ('pending', 'sent', 'failed', 'skipped')),
  attempts integer not null default 0,
  provider_message_id text,
  error_text text,
  response_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (event_id, channel, destination)
);

create index if not exists notification_deliveries_event_idx
  on public.notification_deliveries (event_id);

create table if not exists public.notification_webhook_ingest (
  id uuid primary key default gen_random_uuid(),
  source text not null,
  request_path text,
  request_headers jsonb not null default '{}'::jsonb,
  payload jsonb not null default '{}'::jsonb,
  processed_count integer not null default 0,
  received_at timestamptz not null default timezone('utc', now())
);

alter table public.notification_preferences enable row level security;
alter table public.notification_devices enable row level security;
alter table public.notification_events enable row level security;
alter table public.notification_deliveries enable row level security;
alter table public.notification_webhook_ingest enable row level security;

drop trigger if exists notification_preferences_set_updated_at
  on public.notification_preferences;
create trigger notification_preferences_set_updated_at
before update on public.notification_preferences
for each row execute function public.set_updated_at();

drop trigger if exists notification_devices_set_updated_at
  on public.notification_devices;
create trigger notification_devices_set_updated_at
before update on public.notification_devices
for each row execute function public.set_updated_at();

drop trigger if exists notification_events_set_updated_at
  on public.notification_events;
create trigger notification_events_set_updated_at
before update on public.notification_events
for each row execute function public.set_updated_at();

drop trigger if exists notification_deliveries_set_updated_at
  on public.notification_deliveries;
create trigger notification_deliveries_set_updated_at
before update on public.notification_deliveries
for each row execute function public.set_updated_at();