# Intelligence Tab — Feature Specification

> **Architecture**: Fully client-side Flutter. No backend required. All API calls are made directly from the app. The user's embedded Privy wallet or MWA wallet signs all transactions.

---

## Overview

The Intelligence tab is a **new 5th tab** (between Trade and Positions) with two sub-pages via a `TabBar`:

| Sub-Tab | Feature | What it does |
|---|---|---|
| **Copy Trade** | Mirror top Phoenix traders | Watch known trader addresses client-side; mirror their orders using the user's own wallet |
| **AI Trade** | Autonomous trading bot | Kronos time-series model + Claude Haiku reasoning; executes via Phoenix order API |

**Philosophy**: Both features are user-authorized, non-custodial, always stoppable. Dream never holds keys.

---

## Part 1: Copy Trading

### 1.1 Concept

Users pick a **leader** from a curated list of known Phoenix trader addresses. The app polls the leader's public state and mirrors position changes client-side — scaled to the user's chosen copy size.

### 1.2 User Flow

```
CopyTradePage
 ├── Discover tab
 │    ├── Sorted by: 7d PnL | Win Rate | trades
 │    ├── Trader card: address · 7d ROI · max DD · open positions
 │    └── [Follow] → CopySettingsSheet
 │
 ├── Following tab
 │    ├── Active leaders I'm copying
 │    ├── Per-leader: copy size, gain since follow, [Pause] [Unfollow]
 │    └── Total copy P&L
 │
 └── CopySettingsSheet
      ├── Copy amount (USDC) — absolute or % of collateral
      ├── Max slippage (default 0.5 %)
      ├── Stop-loss on copied position (default −20 %)
      └── [Start Copying]
```

### 1.3 Data Source — Curated Address List

Phoenix API has **no leaderboard endpoint**. The app ships a curated list of known high-performing Phoenix trader addresses. This list is a static JSON file bundled with the app (or fetched from a public GitHub raw URL — no auth, no backend).

```dart
// assets/data/copy_traders.json
[
  {
    "address": "HN7...",
    "label": "Whale #1",
    "twitter": "@trader1"
  },
  ...
]
```

All performance stats are **fetched directly from the Phoenix public API** on demand:
- `GET https://perp-api.phoenix.trade/trader/{authority}/state` → positions, collateral
- `GET https://perp-api.phoenix.trade/trader/{authority}/pnl?resolution=7d` → 7-day PnL
- `GET https://perp-api.phoenix.trade/trader/{authority}/trades-history?limit=50` → trade history

No authentication needed — all endpoints are public.

### 1.4 Copy Engine (Client-Side)

```
CopyTradingNotifier (Riverpod)
  ├── followLeader(address, settings) → persists to SharedPrefs
  ├── unfollowLeader(address)
  ├── _pollLeaders() — runs on a Timer.periodic(10s) for each followed leader
  │     ├── GET /trader/{authority}/state → compare to last known state
  │     ├── if new position detected → _mirrorPosition(leader, userSettings)
  │     └── if position closed → _closeFollowerPosition(leader)
  └── _mirrorPosition(leader, settings)
        ├── Scale size: followerSize = min(leaderSize * settings.ratio, settings.maxUSDC)
        ├── POST /v1/ix/place-isolated-market-order-enhanced
        │     body: { market, side, size, leverage, authority: user.walletAddress }
        ├── Sign tx with PrivyWalletManager or MwaWalletService
        └── Broadcast via Solana RPC
```

**Key points**:
- Polling is managed by a `Timer.periodic` inside the Riverpod notifier — no isolates needed for polling frequency ≥ 5 s
- Followed leaders + settings are persisted in SharedPrefs (`dream_copy_following_v1`)
- If the user pauses, the timer is cancelled; resumed on un-pause
- Position mirroring uses the same `POST /v1/ix/place-isolated-market-order-enhanced` flow already implemented in the Trade tab
- Stop-loss is implemented client-side: poll the follower's own position state; if unrealized PnL ≤ −stopLoss threshold, close automatically

### 1.5 State Model

```dart
class CopyTradingState {
  final List<LeaderProfile> discover;       // all curated leaders with fetched stats
  final List<FollowedLeader> following;     // user's active follows
  final bool isPolling;
  final String? error;
}

class LeaderProfile {
  final String address;
  final String? label;
  final double pnl7d;
  final double winRate;
  final List<PositionSummary> openPositions;
}

class FollowedLeader {
  final LeaderProfile leader;
  final CopySettings settings;
  final double gainSinceFollow;
  final bool isPaused;
}

class CopySettings {
  final double copyUSDC;    // absolute USDC to allocate
  final double maxSlippage; // e.g. 0.005
  final double stopLoss;    // e.g. 0.20 (20% of copy size)
}
```

---

## Part 2: AI Auto-Trading (Intelligence)

### 2.1 Concept

A user configures a simple trading bot. The bot:
1. Reads real-time candle data from Phoenix WebSocket
2. Runs the **Kronos** time-series model to generate a price direction signal
3. Asks **Claude Haiku** to reason over the signal + current positions + risk parameters
4. Executes a Phoenix order if Claude returns a `BUY` or `SELL` action

Everything runs in Flutter — no backend, no server.

### 2.2 User Flow

```
AITradingPage
 ├── Config card
 │    ├── Market selector (e.g. SOL-PERP)
 │    ├── Max position size (USDC)
 │    ├── Max leverage (1×–20×)
 │    ├── Risk mode: Conservative | Balanced | Aggressive
 │    └── [Start Bot] / [Stop Bot]
 │
 ├── Live log feed (tail of last 20 bot decisions)
 │    └── e.g. "12:04 — HOLD. Kronos: neutral. Claude: 'funding rate too high to enter long.'"
 │
 └── Bot P&L card
      └── Total gain/loss since bot started
```

### 2.3 AI Engine (Client-Side)

#### Kronos — Price Direction Signal

Kronos is a lightweight HuggingFace time-series model. Call it directly from Flutter via `dio`:

```dart
final resp = await dio.post(
  'https://api-inference.huggingface.co/models/NeoQuasar/Kronos-small',
  options: Options(headers: {'Authorization': 'Bearer $hfApiKey'}),
  data: {
    'inputs': candlesAsFloatList,   // last 60 close prices
    'parameters': {'prediction_length': 3},
  },
);
// resp.data['generated_text'] or similar → parse direction
```

API key stored in `.env` (`HUGGINGFACE_API_KEY`), loaded via `flutter_dotenv`.

#### Claude Haiku — Reasoning & Decision

After Kronos returns a direction signal, pass context to Claude Haiku:

```dart
final resp = await dio.post(
  'https://api.anthropic.com/v1/messages',
  options: Options(headers: {
    'x-api-key': claudeApiKey,
    'anthropic-version': '2023-06-01',
  }),
  data: {
    'model': 'claude-haiku-4-5',
    'max_tokens': 128,
    'messages': [
      {
        'role': 'user',
        'content': '''
You are a risk-aware trading bot for a Solana perpetuals DEX.
Market: $market
Kronos signal: $kronosSignal (confidence: $confidence)
Current position: $currentPosition
Funding rate: $fundingRate
User max size: $maxUSDC | Max leverage: $maxLeverage | Risk mode: $riskMode

Reply with EXACTLY one line:
ACTION: BUY|SELL|HOLD
REASON: <one sentence>
''',
      }
    ],
  },
);
```

Claude returns a structured decision with reasoning. Parse `ACTION:` to decide execution.

#### Execution Loop

```
AITradingNotifier (Riverpod)
  ├── startBot(config) → schedules _runCycle every 60s
  ├── stopBot()        → cancels timer
  └── _runCycle()
        ├── 1. Fetch last 60 candles from Phoenix WebSocket snapshot
        │      GET /exchange/candles/{market}?resolution=1m&limit=60
        ├── 2. Call Kronos → parse direction signal
        ├── 3. Fetch current trader state (positions, funding)
        ├── 4. Call Claude Haiku → parse ACTION
        ├── 5. if ACTION == BUY or SELL → build + sign + broadcast order
        │      POST /v1/ix/place-isolated-market-order-enhanced
        │      PrivyWalletManager.signMessage() or MwaWalletService.signMessage()
        └── 6. Append to log, update P&L
```

### 2.4 State Model

```dart
class AITradingState {
  final bool isRunning;
  final AIBotConfig? config;
  final List<BotLogEntry> log;   // last 20 decisions
  final double totalPnL;
  final String? error;
}

class AIBotConfig {
  final String market;
  final double maxSizeUSDC;
  final double maxLeverage;
  final RiskMode riskMode;
}

class BotLogEntry {
  final DateTime timestamp;
  final String action;   // BUY / SELL / HOLD
  final String reason;
  final double? executedSize;
}
```

---

## Part 3: Tab Integration

### Navigation

Add Intelligence as tab index 2 (between Trade and Positions):

```dart
// bottom_nav.dart  — add new tab
BottomNavItem(icon: PhosphorIcons.robot(), label: 'Intelligence', index: 2),
```

Update `MainShell` page list accordingly. The existing 4-tab layout shifts Positions and Account to indices 3 and 4.

### Providers

| Provider | Location |
|---|---|
| `copyTradingProvider` | `features/intelligence/providers/copy_trading_provider.dart` |
| `aiTradingProvider` | `features/intelligence/providers/ai_trading_provider.dart` |

### File Structure

```
features/intelligence/
  presentation/
    pages/
      intelligence_tab_page.dart     # TabBar host: Copy Trade | AI
      copy_trade_page.dart
      ai_trading_page.dart
    widgets/
      leader_card.dart
      copy_settings_sheet.dart
      bot_log_tile.dart
  providers/
    copy_trading_provider.dart
    ai_trading_provider.dart
  data/
    copy_traders.json                # Curated trader addresses
```

---

## Environment Variables Required

```
# .env
HUGGINGFACE_API_KEY=hf_...
ANTHROPIC_API_KEY=sk-ant-...
```

Both keys are accessed via `flutter_dotenv` — never embedded in source code.

---

## Key Constraints

- **No backend** — all API calls are client-side (Phoenix, HuggingFace, Anthropic)
- **Non-custodial** — Dream never stores or transmits private keys; Privy SDK handles signing transparently
- **User-stoppable** — bot timer can be cancelled at any time; copy polling stops when user pauses
- **Rate limits** — Kronos/Claude calls are throttled to once per 60 s to stay within free-tier limits; copy polling is every 10 s
- **API key security** — HuggingFace and Anthropic keys are in `.env`, gitignored, and displayed only in Settings behind Face ID
