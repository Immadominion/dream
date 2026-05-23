# Dream

**Perpetual futures trading terminal on Solana** — powered by [Phoenix Trade](https://perp-api.phoenix.trade).

Dream is a mobile-first Flutter app that lets users trade perpetual futures directly from their phone with their Solana wallet — no custodian, no bridge, no compromise.

---

## What It Does

- **Trade perps on Solana** — market and limit orders on Phoenix's on-chain CLOB
- **Real-time market data** — live orderbook, candles, mark price, funding rate via WebSocket
- **Position management** — open positions, P&L, liquidation price at a glance
- **Account overview** — USDC collateral, order history, funding payments
- **Sign in two ways** — Privy embedded wallet (email/OAuth) or external wallet via MWA (Phantom, Solflare)

---

## Tech Stack

| Layer | Choice |
|-------|--------|
| Framework | Flutter (Dart) |
| State | Riverpod (Notifier pattern) |
| Auth | Privy SDK + Solana MWA |
| Trading | Phoenix Trade REST + WebSocket API |
| Revenue | Phoenix Flight builder fee program |
| Storage | Hive + SharedPreferences |
| Blockchain | Solana (`solana` package, Helius RPC) |

---

## Auth Architecture

Two sign-in paths, one unified auth state:

```
Email/OAuth → Privy SDK → embedded Solana wallet  ─┐
                                                    ├──► clientAuthProvider
MWA (Android) → Phantom/Solflare → SIWS + Privy   ─┘
                                                        ↓
                                              phoenixAuthProvider
                                          (Phoenix JWT, auto-refreshes)
```

- `clientAuthProvider` — app-level session; exposes `walletAddress`
- `phoenixAuthProvider` — Phoenix JWT; exposes `accessToken` for trading API calls
- Phoenix JWT auto-refreshes silently; only requires wallet re-sign when refresh token expires

---

## Phoenix Integration

```
GET  /v1/auth/nonce            → sign nonce with wallet
POST /v1/auth/login/wallet     → receive JWT pair
POST /v1/auth/refresh          → silent token refresh (no re-sign)
GET  /exchange/markets         → market list
GET  /v1/exchange/snapshot     → full exchange state
GET  /trader/{pubkey}/state    → positions + orders + collateral
POST /v1/ix/place-isolated-market-order-enhanced → build order tx
POST /v1/ix/place-isolated-limit-order-enhanced  → build limit order tx
WS   /v1/ws                    → orderbook, candles, traderState, allMids
```

Builder fees via [Phoenix Flight](https://flight.phoenix.trade) — Dream earns bps on every taker fill.

---

## Getting Started

```bash
flutter pub get
flutter run
```

Requires a `.env` file in `dream/` with:

```
PRIVY_APP_ID=your_privy_app_id
HELIUS_API_KEY=your_helius_key
PHOENIX_BUILDER_CODE=your_flight_builder_code   # optional: earn builder fees
```

---

## Project Structure

```
lib/
  core/
    constants/app_constants.dart          # All URLs + env-backed keys
    models/phoenix/phoenix_models.dart    # All Phoenix data types
    providers/
      auth/client_auth_provider.dart      # App auth (Privy + MWA)
      phoenix/phoenix_auth_provider.dart  # Phoenix JWT state
    services/
      phoenix/phoenix_auth_service.dart   # Nonce, sign, JWT storage
      wallet/privy_wallet_manager.dart    # Privy embedded wallet
      wallet/mwa_wallet_service.dart      # MWA (Android only)
  features/
    markets/    # Markets list + live prices
    trade/      # Order entry — market + limit
    positions/  # Open positions, P&L
    account/    # Collateral, history, settings
```
