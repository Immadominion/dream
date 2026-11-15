# Dream V2 — Dreams

**Status:** built and verified end-to-end on a local validator running Meteora's
mainnet program. Not yet deployed. Date: 2026-11-15.

## 1. Why

Usage data (Privy, Railway Postgres, Phoenix/Helius on-chain, Sep 2025 → Nov 2026):

| Signal | Value |
|---|---|
| Signups | 21 total, ~1–3/month since June |
| Wallets that ever funded | 2 of 20 (one $5 deposit + one position) |
| Builder fees earned, all-time | $0.078 |
| Copy-trading followers | 1 (owner's wallet), active 2 days in June, 43% mirror failures |
| Copy-point purchases / broadcasters | 0 / 0 |

Perps alone is not pulling users. Copy trading had no users and was burning a
Railway process polling one leader every 6s. V2 keeps perps, **removes copy
trading**, and puts a reason-to-open-the-app in its tab: **Dreams**.

### Market evidence (X, researched 2026-11-15)

| Signal | What it shows |
|---|---|
| [@destiny_ndlovu, Oct 22](https://x.com/destiny_ndlovu/status/2113105441613840769): "an app where you upload your bills and bored billionaires swipe right to pay them" — **7.3M views, 253K likes, 22K reposts, 9.2K bookmarks** | Massive latent demand for the idea. |
| The "Elon Musk said poor people should post their problems…" post | **Does not exist** — fact-checked as fabricated screenshots of the post above. Don't cite Elon in marketing. |
| [@Deucesofweb3, Nov 14](https://x.com/Deucesofweb3/status/2121611082653393361): $1,500 for his father's burial — 4.9K views, 32 reposts, 4 replies ("Pls someone show up") | Needs get attention but no money: no rail to convert it. |
| Live search: "help me raise the remaining $110 so I can pay the rent. Tonight is the final deadline" (9h old) — new posts hourly | Supply of real needs is constant and mostly small ($100–$1,500). |
| "Charity is a scam… 'help me pay my rent' while the person is posting vacation pics"; "you'd open an account and decide to be a beggar" (28K views) | Trust and stigma are the core objections → public on-chain receipts + verification matter more than features. |
| **$TUITION** (paytuition.dev, Sep 27): creator fees → "$10 → $300 → $753 in under an hour", public fund wallet | The coin-for-a-cause mechanism works. |
| **$SOREN** (May): creator fees for a son's surgery; price dumped, holders "panicked", community "Saving $SOREN" | Price volatility is the main risk of the coin path — always pair it with direct funding. |
| **Pay My Billy** (paymybilly.com): US fiat bill-paying, waitlist/pilot, "safety checks got too strict" | Closest competitor — US-only, fiat, not live. Global + crypto + coin attention is open. |
| getbillanthropy.com: "7.2M people saw this. I built it." — **18 views** | Building is easy; distribution is the moat. Launch through people with reach. |
| @MeteoraEco amplifies DBC builders (Best Use of DBC winners, 10K+ views) | Clear repost path: ship on DBC, show on-chain receipts, pitch @MeteoraEco. |

## 2. What Dreams is

Someone posts a real need ("help me pay my final-year fees — $350"). Anyone can:

1. **Fund it directly** — USDC goes wallet → owner's wallet. Dream never holds funds.
2. **Back its coin** — the owner can launch a coin for the dream on Meteora's
   Dynamic Bonding Curve. Every trade pays the owner a fee, so attention on X
   turns into money for the person with the problem.

## 3. Design

```
App (Flutter)                       dream-server (Hono/Postgres)            Solana
─────────────                       ────────────────────────────            ──────
Post dream ──── signed request ───► dreams row (owner = signer wallet)
Fund ── USDC transfer (user signs) ──────────────────────────────────────► owner wallet
     └─ tx sig ───────────────────► getParsedTransaction → verify → credit
Launch coin ─── prepare ──────────► build createPool, mint key partial-signs
            ◄── unsigned tx ──────┘
            ── owner signs + sends ─────────────────────────────────────► DBC pool (creator = owner)
            ── confirm ───────────► read pool on-chain, check config/creator/mint
Buy/Sell ────── swap ─────────────► build swap2 w/ slippage quote
            ── user signs + sends ──────────────────────────────────────► DBC pool
Claim fees ──── claim ────────────► build claimCreatorTradingFee (owner only)
```

**Custody:** the server never sees a user key and never receives user funds.
It builds transactions; the user's wallet (Privy or MWA) signs them. The only
key the server holds is each coin's single-use mint keypair, which is
discarded after signing the creation tx.

**Consent is enforced on-chain:** the DBC program requires the pool *creator*
to sign creation, so a coin can only be launched by the dream's owner —
nobody can launch a coin "for" someone else and pocket the attention.

**Contribution verification** (`src/dreams/contribution.ts`): credited amount is
measured from pre/post token balances of the confirmed tx — must be signed by
the authenticated supporter, move USDC from supporter to owner, succeed, and be
newer than the dream. Idempotent per signature; contributions serialize per
dream with a row lock.

### Coin economics (`src/dreams/curve.ts`, one config for all coins)

| | |
|---|---|
| Trading fee | 1% steady state; anti-sniper 10% → 1% over the first 60s |
| Fee split | Meteora 20% · **owner 64%** · Dream 16% (`creatorTradingFeePercentage = 80`) |
| Paid in | SOL (quote token) |
| Supply | 1B, mint authority immutable — nobody can mint more |
| Curve | 30 SOL → 420 SOL market cap, then migrates to DAMM v2 |
| Liquidity after graduation | 100% permanently locked, split 80/20 owner/Dream — LP fees keep flowing to the owner |
| Launch cost to owner | ~0.025 SOL (measured) |

Config accounts are immutable: to change economics, create a new config and
point `DREAM_DBC_CONFIG` at it. Existing coins keep their config.

### Moderation

Owner-only posting; ≤3 open dreams per wallet; title/goal immutable after
posting; one report per wallet; auto-hide at 5 reports with a Telegram alert;
text sanitized (control/bidi/zero-width stripped); X links restricted to
`x.com/<handle>/status/<id>`; tickers restricted to `[A-Z0-9]` (no lookalikes).

## 4. Verification

| Check | Result |
|---|---|
| Server unit tests (`npm test`) — money, validation, contribution verification, curve | 15/15 |
| Coin lifecycle on localnet with Meteora's mainnet DBC program (`scripts/dbc-localnet-e2e.ts`) — launch, verify, buy, sell, fees accrue, owner claims, stranger can't | pass |
| API end-to-end (`scripts/api-localnet-e2e.ts`) — real server + Postgres + localnet; impersonated/replayed contributions, non-owner launch/claim/close, closed-dream funding, recovery of a launch that landed without `/confirm`, copy routes disabled | 28/28 |
| App signer vs web3.js on a real launch tx (`test/server_transaction_signer_test.dart`) | byte-identical |
| `flutter analyze lib test`, `tsc --noEmit` | clean |

## 4b. Security review (2026-11-15)

An independent audit found 3 High, 5 Medium, 9 Low issues. The core
money paths held (no way to fake or double-count a transfer, or hijack a
coin). Everything below is fixed and covered by tests.

| Finding | Fix |
|---|---|
| **H1** Free wallets could report-bomb any dream into hiding | Only reporters who have funded a dream (≥$1) count toward auto-hide; operator unhide endpoint; holders can always sell a hidden dream's coin |
| **H2** App blind-signed server-built transactions | Client-side allowlist (`server_tx_guard.dart`): exact program/instruction shapes per action, user is fee payer, pinned pool/mint, pinned swap amount + minimum, SOL wrap ≤ amount entered, capped priority fee. MWA now uses `signTransactions` so wallets decode and simulate |
| **H3** Anyone could link someone else's viral X post | X link only accepted after verifying (oEmbed) the post is by that handle and contains the dream's id |
| **M1** Owner could fake support with same-tx round trips | Rejected if the owner co-signs or the supporter gets any token back |
| **M2** Shared, replayable auth header | Domain-separated session: one signed `dream-session:v1` message → 1h HMAC bearer token |
| **M3** No rate limits | Per-IP + per-wallet limits on every route; Telegram throttle |
| **M4** Story could be rewritten after funding | Story and X link frozen once funded |
| **M5** Slippage not shown/checked | Review step shows expected/minimum; default 1%, max 15%; guard pins minimum |
| L1–L9 | Launch race fix, reconcile waits for blockhash expiry, no internal error leaks, honest metadata for hidden/orphaned coins, wider invisible-char stripping + ASCII coin names, `finalized` contributions, persisted pending contributions |

**Pre-existing bug found while fixing H2:** every MWA (Phantom/Solflare)
transaction signature in the app — Phoenix orders, collateral, USDC
transfers — signed the *base64 text* of the transaction instead of its bytes,
so MWA users could not have traded. Fixed in `mwa_wallet_service.dart`
(`signTransactionMessage`), which all callers now use. Also unified the MWA
app identity (sign used `solana.com`, connect used `trydream.fun`, forcing a
re-approval every time). **Verify on a Seeker before release.**

Accepted risks: an owner can snipe their own coin in the launch block (the
10%→1% fee blunts outsiders, not this); sybil self-funding with fresh money;
report moderation still needs a human watching Telegram.

## 5. Launch checklist

1. **Domain:** point `api.trydream.fun` at the Railway service; set
   `PUBLIC_BASE_URL=https://api.trydream.fun`. Coin metadata URIs are written
   on-chain permanently — do this *before* the first launch.
2. **Coin image:** host a permanent image; set `DREAM_COIN_IMAGE_URL`.
3. **Partner key:** generate offline (`solana-keygen new -o dream-partner.json`),
   fund ~0.05 SOL. It is the fee claimer for Dream's share — keep it off servers.
4. **Config:** `SOLANA_RPC_URL=<mainnet> PARTNER_KEYPAIR_PATH=… npm run dbc:create-config`
   (dry run), then `-- --execute`; set the printed `DREAM_DBC_CONFIG`.
5. **Server env:** `COPY_ENGINE_ENABLED=false` (default). Deploy — migration
   `0002_dreams_v2` applies on boot.
6. **Links:** serve `/d/:id` on trydream.fun (preview + "open in app") and
   `/.well-known/assetlinks.json` for App Link verification.
7. **App:** bump version, build release, submit to the dApp Store.
8. **Smoke test on a Seeker with both Privy and MWA wallets** — MWA signs
   transactions via `signMessage` (same as existing trading code); confirm
   Phantom/Solflare/Seed Vault accept it.

## 6. Open items / risks

- **Fraud** is the main product risk. Mitigations above reduce it; they don't
  remove it. Consider "verified" badges (e.g. X account linked via OAuth) next.
- **Wording:** keep "support/fund" language. Never promise returns on coins.
- **Post-graduation fee claims** go through the owner's DAMM v2 position (Meteora
  app); in-app claiming of those is a follow-up.
- **Partner fee claiming** for Dream's share needs an ops script (follow-up).
- **Analytics:** there is no product analytics today — add it before launch so
  V2 can be measured (signup → fund → first dream / first support).
- **Not reachable during research:** Supabase project `mrtvfvmeluviobebcjtg`
  (devices/events) and the Cloudflare AI worker.
- **Dream platform coin:** if launched, don't attach equity or revenue promises
  to holders (securities risk). Launch it on the same DBC config only after V2
  has real usage.
