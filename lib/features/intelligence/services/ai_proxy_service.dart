import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/phoenix/phoenix_auth_service.dart';
import '../../../core/services/wallet/privy_wallet_manager.dart';
import '../../../core/services/wallet/mwa_wallet_service.dart';
import '../models/intelligence_models.dart';

final aiProxyServiceProvider = Provider<AiProxyService>((ref) {
  final logger = ref.watch(loggerServiceProvider);
  final privyWallet = ref.watch(privyWalletManagerProvider);
  final mwaService = ref.watch(mwaWalletServiceProvider);
  final phoenixAuth = ref.watch(phoenixAuthServiceProvider);
  return AiProxyService(
    logger: logger,
    privyWallet: privyWallet,
    mwaService: mwaService,
    phoenixAuthService: phoenixAuth,
  );
});

const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

/// Calls the Dream AI Cloudflare Worker.
///
/// Security model:
///   - AI API keys (HuggingFace, Anthropic) are stored in the Worker as secrets
///   - Flutter proves identity by signing a short-lived message with the wallet
///   - Worker validates the ed25519 signature, checks credits, proxies to AI
///   - No sensitive keys ever touch the device
class AiProxyService {
  final LoggerService _logger;
  final PrivyWalletManager _privyWallet;
  final MwaWalletService _mwaService;
  final PhoenixAuthService _phoenixAuthService;
  late final Dio _dio;

  AiProxyService({
    required LoggerService logger,
    required PrivyWalletManager privyWallet,
    required MwaWalletService mwaService,
    required PhoenixAuthService phoenixAuthService,
  }) : _logger = logger,
       _privyWallet = privyWallet,
       _mwaService = mwaService,
       _phoenixAuthService = phoenixAuthService {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.dreamAiWorkerUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  // ── Credit management ────────────────────────────────────────────────────

  Future<int> fetchCredits(String walletAddress) async {
    try {
      final resp = await _dio.get(
        '/v1/credits/balance',
        queryParameters: {'wallet': walletAddress},
      );
      return (resp.data?['credits'] as num?)?.toInt() ?? 0;
    } catch (e) {
      _logger.error('Failed to fetch credits: $e', tag: '[AI]');
      rethrow;
    }
  }

  /// Called after the user sends on-chain SOL to Dream treasury.
  /// [txSignature] — confirmed Solana tx signature of the payment.
  Future<int> topUpCredits({
    required String walletAddress,
    required String txSignature,
  }) async {
    try {
      final resp = await _dio.post(
        '/v1/credits/topup',
        data: {'wallet': walletAddress, 'txSig': txSignature},
      );
      return (resp.data?['credits'] as num?)?.toInt() ?? 0;
    } catch (e) {
      _logger.error('Failed to top up credits: $e', tag: '[AI]');
      rethrow;
    }
  }

  // ── AI calls ─────────────────────────────────────────────────────────────

  /// Runs a full AI cycle: Kronos signal → Claude decision.
  /// Returns (action, reason, kronosSignal, confidence).
  Future<({BotAction action, String reason, String signal, double confidence})>
  runAICycle({
    required String walletAddress,
    required List<double> closePrices,
    required String market,
    required String? currentPosition,
    required double fundingRate,
    required AIBotConfig config,
  }) async {
    final authHeaders = await _buildAuthHeaders(walletAddress);

    // Step 1: Kronos — price direction signal
    String kronosSignal = 'neutral';
    double confidence = 0.5;
    try {
      final kronosResp = await _dio.post(
        '/v1/ai/kronos',
        options: Options(headers: authHeaders),
        data: {'candles': closePrices, 'market': market},
      );
      kronosSignal = kronosResp.data?['signal'] as String? ?? 'neutral';
      confidence =
          (kronosResp.data?['confidence'] as num?)?.toDouble() ?? 0.5;
    } catch (e) {
      _logger.error('Kronos call failed: $e', tag: '[AI]');
    }

    // Step 2: Claude Haiku — reasoning + decision
    try {
      final claudeResp = await _dio.post(
        '/v1/ai/claude',
        options: Options(headers: authHeaders),
        data: {
          'market': market,
          'kronosSignal': kronosSignal,
          'confidence': confidence,
          'currentPosition': currentPosition ?? 'none',
          'fundingRate': fundingRate,
          'maxSizeUSDC': config.maxSizeUSDC,
          'maxLeverage': config.maxLeverage,
          'riskMode': config.riskMode.name,
        },
      );
      final raw = claudeResp.data?['response'] as String? ?? 'HOLD\nneutral';
      return _parseClaudeResponse(raw, kronosSignal, confidence);
    } catch (e) {
      _logger.error('Claude call failed: $e', tag: '[AI]');
      return (
        action: BotAction.hold,
        reason: 'AI unavailable — holding',
        signal: kronosSignal,
        confidence: confidence,
      );
    }
  }

  // ── Internal helpers ─────────────────────────────────────────────────────

  /// Build wallet-signed auth headers.
  /// The signature proves "I am this wallet" without any API key.
  Future<Map<String, String>> _buildAuthHeaders(
    String walletAddress,
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final message = 'dream-ai:$walletAddress:$timestamp';

    String signature;
    try {
      final isMwa =
          _phoenixAuthService.persistedWalletType == 'mwa' &&
          _mwaService.connectedPublicKey == walletAddress;

      if (isMwa) {
        // MWA: signMessage expects base64-encoded bytes
        final msgBytes = Uint8List.fromList(utf8.encode(message));
        final result = await _mwaService.signMessage(base64Encode(msgBytes));
        signature = result.success && result.signature != null
            ? base64Encode(result.signature!)
            : '';
      } else {
        // Privy embedded wallet: signMessage takes a plain String
        final wallet = await _privyWallet.getOrCreateWallet();
        if (wallet == null) throw Exception('No wallet available');
        signature = await _privyWallet.signMessage(wallet, message) ?? '';
      }
    } catch (e) {
      _logger.error('Failed to sign auth message: $e', tag: '[AI]');
      signature = '';
    }

    return {
      'X-Wallet-Address': walletAddress,
      'X-Wallet-Signature': signature,
      'X-Timestamp': timestamp,
    };
  }

  ({BotAction action, String reason, String signal, double confidence})
  _parseClaudeResponse(
    String raw,
    String kronosSignal,
    double confidence,
  ) {
    final lines = raw.toUpperCase().split('\n');
    BotAction action = BotAction.hold;
    String reason = 'No reason provided.';

    for (final line in lines) {
      if (line.contains('ACTION:')) {
        final part = line.split('ACTION:').last.trim();
        if (part.contains('BUY')) action = BotAction.buy;
        if (part.contains('SELL')) action = BotAction.sell;
      }
      if (line.toLowerCase().contains('reason:')) {
        reason = raw
            .split(RegExp(r'REASON:', caseSensitive: false))
            .last
            .trim();
      }
    }

    return (
      action: action,
      reason: reason,
      signal: kronosSignal,
      confidence: confidence,
    );
  }

  // ── Secure key cache (optional user-supplied HF/Claude keys) ────────────
  // If the user adds their own keys in Settings, they bypass credits entirely.

  static const _hfKeyStorageKey = 'dream_intelligence_hf_key';
  static const _claudeKeyStorageKey = 'dream_intelligence_claude_key';

  Future<String?> getUserHFKey() =>
      _secureStorage.read(key: _hfKeyStorageKey);
  Future<void> setUserHFKey(String key) =>
      _secureStorage.write(key: _hfKeyStorageKey, value: key);

  Future<String?> getUserClaudeKey() =>
      _secureStorage.read(key: _claudeKeyStorageKey);
  Future<void> setUserClaudeKey(String key) =>
      _secureStorage.write(key: _claudeKeyStorageKey, value: key);

  Future<void> clearUserKeys() async {
    await _secureStorage.delete(key: _hfKeyStorageKey);
    await _secureStorage.delete(key: _claudeKeyStorageKey);
  }
}
