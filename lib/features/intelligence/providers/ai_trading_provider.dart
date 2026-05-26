import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth/client_auth_provider.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/phoenix/phoenix_order_service.dart';
import '../models/intelligence_models.dart';
import '../services/ai_proxy_service.dart';
import '../services/intelligence_payment_service.dart';

final aiTradingProvider =
    NotifierProvider<AITradingNotifier, AITradingState>(
  AITradingNotifier.new,
);

class AITradingNotifier extends Notifier<AITradingState> {
  Timer? _botTimer;
  static const _cycleInterval = Duration(minutes: 1);
  // Rolling 60-candle window for Kronos
  final List<double> _priceBuffer = [];

  @override
  AITradingState build() {
    ref.onDispose(_stopBot);
    Future.microtask(_loadCredits);
    return const AITradingState();
  }

  // ── Credits ───────────────────────────────────────────────────────────────

  Future<void> _loadCredits() async {
    final wallet = ref.read(clientAuthProvider).walletAddress ?? '';
    if (wallet.isEmpty) return;
    state = state.copyWith(isLoadingCredits: true);
    try {
      final aiService = ref.read(aiProxyServiceProvider);
      final credits = await aiService.fetchCredits(wallet);
      state = state.copyWith(aiCredits: credits, isLoadingCredits: false);
    } catch (e) {
      state = state.copyWith(isLoadingCredits: false);
    }
  }

  Future<void> purchaseCredits(CreditTier tier) async {
    state = state.copyWith(isBuying: true, clearError: true);
    final wallet = ref.read(clientAuthProvider).walletAddress ?? '';
    try {
      // 1. Broadcast on-chain SOL payment
      final paymentService = ref.read(intelligencePaymentServiceProvider);
      final txSig = await paymentService.purchaseCredits(tier);

      // 2. Notify Worker to issue credits
      final aiService = ref.read(aiProxyServiceProvider);
      final newCredits = await aiService.topUpCredits(
        walletAddress: wallet,
        txSignature: txSig,
      );

      state = state.copyWith(aiCredits: newCredits, isBuying: false);

      ref.read(loggerServiceProvider).info(
        'Credits purchased: $newCredits (tx: $txSig)',
        tag: '[AI]',
      );
    } catch (e) {
      state = state.copyWith(isBuying: false, error: e.toString());
    }
  }

  // ── Bot lifecycle ─────────────────────────────────────────────────────────

  void startBot({AIBotConfig? config}) {
    if (state.isRunning) return;
    final cfg = config ?? state.config;
    state = state.copyWith(isRunning: true, config: cfg, clearError: true);
    _botTimer = Timer.periodic(_cycleInterval, (_) => _runCycle());
    // Run immediately on start
    _runCycle();
  }

  void stopBot() {
    _stopBot();
    state = state.copyWith(isRunning: false);
  }

  void updateConfig(AIBotConfig config) {
    state = state.copyWith(config: config);
  }

  void _stopBot() {
    _botTimer?.cancel();
    _botTimer = null;
  }

  // ── Bot cycle ─────────────────────────────────────────────────────────────

  Future<void> _runCycle() async {
    final wallet = ref.read(clientAuthProvider).walletAddress ?? '';
    if (wallet.isEmpty) return;

    final logger = ref.read(loggerServiceProvider);
    final aiService = ref.read(aiProxyServiceProvider);

    // Check credits first
    if (state.aiCredits <= 0) {
      _appendLog(BotLogEntry(
        timestamp: DateTime.now(),
        action: BotAction.hold,
        reason: 'No AI credits remaining — purchase more to continue',
      ));
      stopBot();
      return;
    }

    logger.info('Running AI cycle for ${state.config.market}', tag: '[AI]');

    try {
      // 1. Fetch recent candles
      final candles = await _fetchCandles(state.config.market);
      if (candles.length < 5) {
        logger.warning('Insufficient candle data', tag: '[AI]');
        return;
      }
      _priceBuffer
        ..addAll(candles)
        ..removeRange(0, (_priceBuffer.length - 60).clamp(0, _priceBuffer.length));

      // 2. Get current position (if any)
      final currentPosition = await _getCurrentPosition(
        wallet,
        state.config.market,
      );

      // 3. Get current funding rate
      final fundingRate = await _getFundingRate(state.config.market);

      // 4. Call AI
      final result = await aiService.runAICycle(
        walletAddress: wallet,
        closePrices: List.from(_priceBuffer),
        market: state.config.market,
        currentPosition: currentPosition,
        fundingRate: fundingRate,
        config: state.config,
      );

      // 5. Deduct credit locally (Worker already deducted server-side)
      state = state.copyWith(aiCredits: (state.aiCredits - 1).clamp(0, 99999));

      // 6. Execute trade if needed
      String? txSig;
      if (result.action != BotAction.hold) {
        txSig = await _executeTrade(result.action, wallet);
      }

      // 7. Append log entry
      _appendLog(BotLogEntry(
        timestamp: DateTime.now(),
        action: result.action,
        reason: '${result.reason} (${result.signal}, ${(result.confidence * 100).toStringAsFixed(0)}% conf)',
        txSignature: txSig,
      ));
    } catch (e) {
      logger.error('Bot cycle error: $e', tag: '[AI]');
      _appendLog(BotLogEntry(
        timestamp: DateTime.now(),
        action: BotAction.hold,
        reason: 'Error: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e}',
      ));
    }
  }

  // ── Trade execution ───────────────────────────────────────────────────────

  Future<String?> _executeTrade(BotAction action, String wallet) async {
    final orderService = ref.read(phoenixOrderServiceProvider);
    final logger = ref.read(loggerServiceProvider);
    final config = state.config;

    try {
      final side = action == BotAction.buy ? 'buy' : 'sell';
      // Size = maxSizeUSDC / current price — use last known candle price
      final price = _priceBuffer.isNotEmpty ? _priceBuffer.last : 0;
      final quantity = price > 0 ? config.maxSizeUSDC / price : 0.001;
      final transferMicro = (config.maxSizeUSDC * 1e6).toInt();

      final result = await orderService.placeMarketOrder(
        authority: wallet,
        symbol: config.market,
        side: side,
        quantity: quantity,
        transferAmountUsdc: transferMicro,
      );

      if (result.success) {
        logger.info('AI order placed: ${result.txSignature}', tag: '[AI]');
        return result.txSignature;
      }
      logger.error('AI order failed: ${result.error}', tag: '[AI]');
      return null;
    } catch (e) {
      logger.error('Trade execution error: $e', tag: '[AI]');
      return null;
    }
  }

  // ── Phoenix data helpers ──────────────────────────────────────────────────

  Future<List<double>> _fetchCandles(String market) async {
    try {
      final symbol = market.replaceAll('-PERP', '').toLowerCase();
      final dio = Dio(
        BaseOptions(
          baseUrl: AppConstants.phoenixApiBaseUrl,
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final resp = await dio.get(
        '/candles',
        queryParameters: {
          'symbol': symbol,
          'resolution': '1',
          'limit': 60,
        },
      );
      final data = resp.data;
      List<dynamic> candles;
      if (data is List) {
        candles = data;
      } else if (data is Map && data['candles'] is List) {
        candles = data['candles'] as List;
      } else {
        return [];
      }
      return candles
          .cast<Map<String, dynamic>>()
          .map((c) => (c['close'] as num?)?.toDouble() ?? 0.0)
          .where((p) => p > 0)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<String?> _getCurrentPosition(String wallet, String market) async {
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: AppConstants.phoenixApiBaseUrl,
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final resp = await dio.get('/trader/$wallet/state');
      final data = resp.data as Map<String, dynamic>?;
      if (data == null) return null;
      final positions =
          (data['positions'] ?? data['trader_positions']) as List<dynamic>?;
      if (positions == null) return null;
      for (final p in positions) {
        final pos = p as Map<String, dynamic>;
        if ((pos['symbol'] as String?)?.contains(
              market.replaceAll('-PERP', ''),
            ) ??
            false) {
          return pos['side'] as String?;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<double> _getFundingRate(String market) async {
    try {
      final symbol = market.replaceAll('-PERP', '').toLowerCase();
      final dio = Dio(
        BaseOptions(
          baseUrl: AppConstants.phoenixApiBaseUrl,
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final resp = await dio.get('/exchange/funding-rate/$symbol');
      final data = resp.data as Map<String, dynamic>?;
      return (data?['funding_rate'] as num?)?.toDouble() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  void _appendLog(BotLogEntry entry) {
    final updated = [entry, ...state.log].take(20).toList();
    // Update total P&L based on executed orders (simplistic — track via log)
    state = state.copyWith(log: updated);
  }
}
