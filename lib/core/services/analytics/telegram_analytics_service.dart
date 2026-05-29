import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_constants.dart';
import '../logger_service.dart';
import '../../../shared/services/storage_service.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final telegramAnalyticsProvider = Provider<TelegramAnalyticsService>((ref) {
  final logger = ref.watch(loggerServiceProvider);
  final service = TelegramAnalyticsService(logger: logger);
  service.init(); // dotenv is loaded before any provider is first accessed
  ref.onDispose(service.dispose);
  return service;
});

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Sends real-time analytics events to the developer's Telegram chat.
///
/// Setup (one-time):
///   1. Message @Dream_The_Bot on Telegram → send /start
///   2. Visit https://api.telegram.org/bot<TOKEN>/getUpdates to get your chat_id
///   3. Add to .env:
///        TELEGRAM_BOT_TOKEN=<token>
///        TELEGRAM_CHAT_ID=<your_numeric_chat_id>
///
/// Push events (fired automatically):
///   - 🆕 New user signup (once per wallet address per device)
///   - 📊 Trade opened (every successful order)
///   - 🔒 Position closed
///   - 💰 Collateral deposit
///
/// Slash commands (while app is open on any device):
///   /stats   — Live Phoenix market overview
///   /fees    — Builder fee account status
///   /ping    — Health check
///   /help    — List commands
class TelegramAnalyticsService {
  final LoggerService _logger;

  late final Dio _dio;
  String? _botToken;
  int? _chatId;
  Timer? _pollTimer;
  int _lastUpdateId = 0;
  bool _initialized = false;

  // Storage key prefix: tracks which wallets have already been reported
  static const _kReportedPrefix = 'tg_reported_';

  TelegramAnalyticsService({required LoggerService logger})
      : _logger = logger {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 6),
      ),
    );
  }

  // ── Init / dispose ──────────────────────────────────────────────────────

  void init() {
    final token = dotenv.maybeGet('TELEGRAM_BOT_TOKEN');
    final chatIdStr = dotenv.maybeGet('TELEGRAM_CHAT_ID');

    if (token == null ||
        token.isEmpty ||
        chatIdStr == null ||
        chatIdStr.isEmpty) {
      _logger.info(
        'TelegramAnalytics: TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID not set — analytics disabled',
        tag: 'Analytics',
      );
      return;
    }

    _botToken = token;
    _chatId = int.tryParse(chatIdStr);

    if (_chatId == null) {
      _logger.error(
        'TelegramAnalytics: TELEGRAM_CHAT_ID is not a valid integer',
        tag: 'Analytics',
      );
      return;
    }

    _initialized = true;
    _startPolling();
    _logger.info(
      'TelegramAnalytics: initialized (chatId=$_chatId)',
      tag: 'Analytics',
    );
  }

  void dispose() {
    _pollTimer?.cancel();
  }

  // ── Push events ─────────────────────────────────────────────────────────

  /// Call when a user first authenticates with Phoenix.
  /// Fires only once per wallet address per device install.
  Future<void> trackNewUser(String walletAddress) async {
    if (!_initialized) return;

    final key = '$_kReportedPrefix$walletAddress';
    if (StorageService.getString(key) == 'true') return;
    await StorageService.setString(key, 'true');

    await _send(
      '🆕 *New User*\n'
      '`$walletAddress`\n'
      '🕐 ${_nowUtc()}',
    );
  }

  /// Call after a successful order submission.
  Future<void> trackOrderPlaced({
    required String symbol,
    required String side, // 'buy' | 'sell'
    required String orderType, // 'market' | 'limit'
    required double sizeUsdc,
    required double leverage,
    required double notionalUsdc,
    required double entryPrice,
    required String txSignature,
  }) async {
    if (!_initialized) return;

    final emoji = side == 'buy' ? '🟢' : '🔴';
    final dir = side == 'buy' ? 'LONG' : 'SHORT';
    final typeLabel = orderType == 'market' ? 'Market' : 'Limit';

    await _send(
      '$emoji *Trade Opened* — $typeLabel\n'
      '📊 `$symbol` · *$dir* · ${leverage.toStringAsFixed(0)}x\n'
      '💵 Collateral: \$${sizeUsdc.toStringAsFixed(2)} USDC\n'
      '📐 Notional: \$${notionalUsdc.toStringAsFixed(2)} USDC\n'
      '🎯 Entry: \$${entryPrice.toStringAsFixed(4)}\n'
      '🔗 [View TX](https://solscan.io/tx/$txSignature)',
    );
  }

  /// Call when a position is closed.
  Future<void> trackPositionClosed({
    required String symbol,
    required String side, // 'buy' | 'sell'
    double? pnlUsdc,
  }) async {
    if (!_initialized) return;

    final pnlStr = pnlUsdc != null
        ? (pnlUsdc >= 0
              ? '✅ +\$${pnlUsdc.toStringAsFixed(2)}'
              : '❌ \$${pnlUsdc.toStringAsFixed(2)}')
        : 'N/A';

    await _send(
      '🔒 *Position Closed*\n'
      '📊 `$symbol` · ${side == 'buy' ? 'LONG' : 'SHORT'}\n'
      '💸 PnL: $pnlStr',
    );
  }

  /// Call after a successful collateral deposit.
  Future<void> trackCollateralDeposit(
    String walletAddress,
    double amountUsdc,
  ) async {
    if (!_initialized) return;

    await _send(
      '💰 *Collateral Deposit*\n'
      '👛 `${_short(walletAddress)}`\n'
      '💵 \$${amountUsdc.toStringAsFixed(2)} USDC',
    );
  }

  // ── Slash command polling ───────────────────────────────────────────────

  void _startPolling() {
    // Poll every 30 s while the app is active
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _poll());
    // Also poll immediately so commands sent while the app was closed are handled
    _poll();
  }

  Future<void> _poll() async {
    if (!_initialized) return;
    try {
      final resp = await _dio.get(
        'https://api.telegram.org/bot$_botToken/getUpdates',
        queryParameters: {
          'offset': _lastUpdateId + 1,
          'timeout': 0,
          'allowed_updates': ['message'],
        },
      );

      final updates = (resp.data['result'] as List?) ?? [];
      for (final update in updates) {
        final id = update['update_id'] as int? ?? 0;
        if (id > _lastUpdateId) _lastUpdateId = id;

        final msg = update['message'];
        if (msg == null) continue;

        // Only respond to the developer's chat
        final fromId = msg['chat']?['id'];
        if (fromId != _chatId) continue;

        final text = (msg['text'] as String? ?? '').trim().toLowerCase();
        await _handleCommand(text);
      }
    } catch (_) {
      // Network errors during polling are non-fatal — silently swallow
    }
  }

  Future<void> _handleCommand(String text) async {
    if (text == '/start' || text == '/help') {
      await _send(
        '🤖 *Dream Terminal Analytics*\n\n'
        '/stats — Live Phoenix market overview\n'
        '/fees — Builder fee account status\n'
        '/ping — Health check\n'
        '/help — This message',
      );
    } else if (text == '/ping') {
      await _send('✅ Dream Terminal is live\n🕐 ${_nowUtc()}');
    } else if (text == '/stats') {
      await _handleStats();
    } else if (text == '/fees') {
      await _handleFees();
    }
  }

  Future<void> _handleStats() async {
    try {
      final resp = await _dio.get(
        '${AppConstants.phoenixApiBaseUrl}/exchange/markets',
      );
      final markets = (resp.data as List?) ?? [];
      final sb = StringBuffer('📊 *Phoenix Markets*\n\n');

      for (final m in markets.take(5)) {
        final symbol = m['symbol'] ?? m['marketId'] ?? '?';
        final price = m['markPrice'] ?? m['indexPrice'] ?? m['lastPrice'] ?? 0;
        final change = m['priceChange24h'] ?? m['change24h'];
        final vol = m['volume24hUsd'] ?? m['volume24h'];

        String changeStr = '';
        if (change != null) {
          final d = double.tryParse(change.toString()) ?? 0;
          changeStr = d >= 0 ? ' ▲${d.toStringAsFixed(2)}%' : ' ▼${d.abs().toStringAsFixed(2)}%';
        }
        final volStr = vol != null ? ' · Vol \$${_vol(vol)}' : '';
        sb.writeln('`$symbol` \$${_price(price)}$changeStr$volStr');
      }

      sb.write('\n🕐 ${_nowUtc()}');
      await _send(sb.toString());
    } catch (e) {
      await _send('⚠️ Could not fetch market data');
    }
  }

  Future<void> _handleFees() async {
    final authority = dotenv.maybeGet('PHOENIX_BUILDER_AUTHORITY');
    if (authority == null || authority.isEmpty) {
      await _send('⚠️ PHOENIX\\_BUILDER\\_AUTHORITY not configured');
      return;
    }

    try {
      final resp = await _dio.get(
        '${AppConstants.phoenixApiBaseUrl}/trader/$authority/state',
      );
      final data = resp.data as Map<String, dynamic>? ?? {};

      final collateral =
          data['collateral'] ?? data['availableCollateral'] ?? data['freeCollateral'] ?? 0;
      final unrealizedPnl = data['unrealizedPnl'] ?? data['pnl'] ?? 0;

      await _send(
        '🏦 *Builder Fee Account*\n'
        '👛 `${_short(authority)}`\n'
        '💵 Collateral: \$${_price(collateral)} USDC\n'
        '📈 Unrealized PnL: \$${_price(unrealizedPnl)}\n'
        '🕐 ${_nowUtc()}',
      );
    } catch (e) {
      await _send('⚠️ Could not fetch builder fee data');
    }
  }

  // ── Core send ───────────────────────────────────────────────────────────

  Future<void> _send(String text) async {
    if (!_initialized || _botToken == null || _chatId == null) return;
    try {
      await _dio.post(
        'https://api.telegram.org/bot$_botToken/sendMessage',
        data: {
          'chat_id': _chatId,
          'text': text,
          'parse_mode': 'Markdown',
          'disable_web_page_preview': true,
        },
      );
    } catch (e) {
      _logger.error(
        'TelegramAnalytics: sendMessage failed',
        error: e,
        tag: 'Analytics',
      );
    }
  }

  // ── Formatting helpers ──────────────────────────────────────────────────

  String _short(String addr) => addr.length > 10
      ? '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}'
      : addr;

  String _nowUtc() {
    final n = DateTime.now().toUtc();
    return '${n.year}-${_p(n.month)}-${_p(n.day)} ${_p(n.hour)}:${_p(n.minute)} UTC';
  }

  String _p(int v) => v.toString().padLeft(2, '0');

  String _price(dynamic v) {
    final d = double.tryParse(v.toString()) ?? 0;
    return d >= 1000
        ? d.toStringAsFixed(2)
        : d.toStringAsFixed(d < 1 ? 4 : 2);
  }

  String _vol(dynamic v) {
    final d = double.tryParse(v.toString()) ?? 0;
    if (d >= 1e9) return '${(d / 1e9).toStringAsFixed(1)}B';
    if (d >= 1e6) return '${(d / 1e6).toStringAsFixed(1)}M';
    if (d >= 1e3) return '${(d / 1e3).toStringAsFixed(1)}K';
    return d.toStringAsFixed(0);
  }
}
