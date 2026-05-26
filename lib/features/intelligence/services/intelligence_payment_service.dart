import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solana/base58.dart';
import 'package:solana/solana.dart' as solana;

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth/client_auth_provider.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/phoenix/phoenix_auth_service.dart';
import '../../../core/services/wallet/privy_wallet_manager.dart';
import '../../../core/services/wallet/mwa_wallet_service.dart';
import '../models/intelligence_models.dart';

final intelligencePaymentServiceProvider =
    Provider<IntelligencePaymentService>((ref) {
  final logger = ref.watch(loggerServiceProvider);
  final privyWallet = ref.watch(privyWalletManagerProvider);
  final mwaService = ref.watch(mwaWalletServiceProvider);
  final phoenixAuth = ref.watch(phoenixAuthServiceProvider);
  final auth = ref.watch(clientAuthProvider);
  return IntelligencePaymentService(
    logger: logger,
    privyWallet: privyWallet,
    mwaService: mwaService,
    phoenixAuthService: phoenixAuth,
    walletAddress: auth.walletAddress ?? '',
  );
});

/// Handles on-chain SOL micropayments to the Dream treasury wallet.
///
/// The x402-inspired payment model:
///   1. User selects a credit tier (e.g. 50 credits for 0.02 SOL).
///   2. This service builds a SOL transfer tx and signs it via Privy or MWA.
///   3. The tx is broadcast to Solana.
///   4. The confirmed tx signature is passed to [AiProxyService.topUpCredits()]
///      so the Cloudflare Worker can verify on-chain and add credits to the KV.
class IntelligencePaymentService {
  final LoggerService _logger;
  final PrivyWalletManager _privyWallet;
  final MwaWalletService _mwaService;
  final PhoenixAuthService _phoenixAuthService;
  final String _walletAddress;
  late final solana.SolanaClient _solana;

  IntelligencePaymentService({
    required LoggerService logger,
    required PrivyWalletManager privyWallet,
    required MwaWalletService mwaService,
    required PhoenixAuthService phoenixAuthService,
    required String walletAddress,
  }) : _logger = logger,
       _privyWallet = privyWallet,
       _mwaService = mwaService,
       _phoenixAuthService = phoenixAuthService,
       _walletAddress = walletAddress {
    _solana = solana.SolanaClient(
      rpcUrl: Uri.parse(AppConstants.heliusRpcUrl),
      websocketUrl: Uri.parse(
        AppConstants.heliusRpcUrl.replaceFirst('https', 'wss'),
      ),
    );
  }

  /// Build, sign, and broadcast a SOL transfer for the given credit tier.
  /// Returns the confirmed transaction signature on success.
  Future<String> purchaseCredits(CreditTier tier) async {
    if (_walletAddress.isEmpty) {
      throw Exception('No wallet connected');
    }
    if (AppConstants.dreamTreasuryAddress.isEmpty) {
      throw Exception('Dream treasury address not configured');
    }

    const lamportsPerSol = 1000000000;
    final lamports = (tier.solPrice * lamportsPerSol).round();

    _logger.info(
      'Purchasing ${tier.credits} credits: ${tier.solPrice} SOL → treasury',
      tag: '[Payment]',
    );

    try {
      // Build SOL transfer message bytes
      final bh = await _solana.rpcClient.getLatestBlockhash(
        commitment: solana.Commitment.confirmed,
      );
      final blockhash = bh.value.blockhash;

      final messageBytes = _buildTransferMessage(
        from: _walletAddress,
        to: AppConstants.dreamTreasuryAddress,
        lamports: lamports,
        recentBlockhash: blockhash,
      );

      // Sign
      final signatureBytes = await _sign(messageBytes);

      // Assemble: compact-u16(1) + sig(64) + message
      final builder = BytesBuilder();
      builder.add(_compactU16(1));
      builder.add(signatureBytes);
      builder.add(messageBytes);
      final signedTx = builder.toBytes();

      // Broadcast
      final txSig = await _solana.rpcClient.sendTransaction(
        base64Encode(signedTx),
        preflightCommitment: solana.Commitment.confirmed,
      );

      _logger.info('Payment tx sent: $txSig', tag: '[Payment]');

      // Wait for confirmation
      await _waitForConfirmation(txSig);
      return txSig;
    } catch (e) {
      _logger.error('Payment failed: $e', tag: '[Payment]');
      rethrow;
    }
  }

  Future<List<int>> _sign(List<int> messageBytes) async {
    final isMwa =
        _phoenixAuthService.persistedWalletType == 'mwa' &&
        _mwaService.connectedPublicKey == _walletAddress;

    if (isMwa) {
      final result =
          await _mwaService.signMessage(base64Encode(messageBytes));
      if (!result.success || result.signature == null) {
        throw Exception('MWA signing failed: ${result.error}');
      }
      return result.signature!.toList();
    }

    final wallet = await _privyWallet.getOrCreateWallet();
    if (wallet == null) throw Exception('No wallet available');
    final sigBase64 = await _privyWallet.signTransaction(
      wallet,
      Uint8List.fromList(messageBytes),
    );
    if (sigBase64 == null) throw Exception('Privy signing failed');
    return base64Decode(sigBase64).toList();
  }

  /// Build a minimal Solana legacy message for a SOL transfer.
  List<int> _buildTransferMessage({
    required String from,
    required String to,
    required int lamports,
    required String recentBlockhash,
  }) {
    // SystemProgram ID
    const systemProgram = '11111111111111111111111111111111';

    final accounts = [from, to, systemProgram];
    final accountsEncoded = accounts
        .map((a) => base58decode(a).toList())
        .toList();

    // Header: numRequired=1, numReadonlyRequired=0, numReadonlyUnrequired=1
    final header = [1, 0, 1];

    // Blockhash (32 bytes)
    final blockhashBytes = base58decode(recentBlockhash);

    // SystemProgram transfer instruction data: [2, 0, 0, 0] + lamports (8 bytes LE)
    final lamportBytes = Uint8List(8);
    final bd = ByteData.view(lamportBytes.buffer);
    bd.setUint64(0, lamports, Endian.little);

    final instrData = Uint8List.fromList([2, 0, 0, 0, ...lamportBytes]);

    // Instruction: program index (2) + account indices [0,1] + data
    final instrAccountIndices = [0, 1];

    final out = BytesBuilder();
    // Header
    out.add(header);
    // Account addresses
    out.add(_compactU16(accounts.length));
    for (final a in accountsEncoded) {
      out.add(a);
    }
    // Blockhash
    out.add(blockhashBytes);
    // Instruction count
    out.add(_compactU16(1));
    // Instruction
    out.addByte(2); // program id index (SystemProgram)
    out.add(_compactU16(instrAccountIndices.length));
    for (final idx in instrAccountIndices) {
      out.addByte(idx);
    }
    out.add(_compactU16(instrData.length));
    out.add(instrData);

    return out.toBytes().toList();
  }

  List<int> _compactU16(int value) {
    if (value <= 0x7f) return [value];
    if (value <= 0x3fff) {
      return [(value & 0x7f) | 0x80, (value >> 7) & 0xff];
    }
    return [
      (value & 0x7f) | 0x80,
      ((value >> 7) & 0x7f) | 0x80,
      (value >> 14) & 0xff,
    ];
  }

  Future<void> _waitForConfirmation(
    String txSignature, {
    int maxAttempts = 30,
  }) async {
    for (var i = 0; i < maxAttempts; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      try {
        final statuses = await _solana.rpcClient.getSignatureStatuses(
          [txSignature],
        );
        final status = statuses.value.first;
        if (status?.confirmationStatus != null) return;
      } catch (_) {
        // retry
      }
    }
    throw Exception('Transaction not confirmed within 30 seconds');
  }
}
