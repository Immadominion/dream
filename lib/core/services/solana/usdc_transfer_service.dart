import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart' as solana;

import '../../constants/app_constants.dart';
import '../logger_service.dart';
import '../wallet/mwa_wallet_service.dart';
import '../wallet/privy_wallet_manager.dart';
import 'solana_transaction_service.dart';

/// Service for sending USDC (SPL token transfers) from the user's connected
/// wallet to an arbitrary Solana address.
///
/// Wallet model: signing is delegated to whichever wallet the user authenticated
/// with — Privy embedded wallet OR MWA-connected wallet (Phantom/Solflare).
class UsdcTransferService {
  static const String usdcMint = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
  static const int usdcDecimals = 6;

  final LoggerService _logger;
  final PrivyWalletManager _privyWallet;
  final MwaWalletService _mwaService;
  final SolanaTransactionService _baseTxService; // for wallet-type detection
  late final solana.SolanaClient _solana;

  UsdcTransferService({
    required LoggerService logger,
    required PrivyWalletManager privyWallet,
    required MwaWalletService mwaService,
    required SolanaTransactionService baseTxService,
  }) : _logger = logger,
       _privyWallet = privyWallet,
       _mwaService = mwaService,
       _baseTxService = baseTxService {
    _solana = solana.SolanaClient(
      rpcUrl: Uri.parse(AppConstants.heliusRpcUrl),
      websocketUrl: Uri.parse(
        AppConstants.heliusRpcUrl.replaceFirst('https', 'wss'),
      ),
    );
  }

  /// Send [amountUsdc] USDC from [fromOwner] to [toOwner].
  ///
  /// - Verifies the destination address is a valid base58 Solana pubkey.
  /// - Derives both owners' USDC associated token accounts.
  /// - Auto-creates the recipient's USDC ATA if missing (fee payer = sender).
  /// - Submits a single legacy transaction signed by the user's wallet.
  Future<TransactionResult> sendUsdc({
    required String fromOwner,
    required String toOwner,
    required double amountUsdc,
  }) async {
    try {
      if (amountUsdc <= 0) {
        return TransactionResult.failure('Amount must be greater than 0');
      }

      // Validate addresses (throws on invalid base58 / wrong length)
      final solana.Ed25519HDPublicKey fromPk;
      final solana.Ed25519HDPublicKey toPk;
      try {
        fromPk = solana.Ed25519HDPublicKey.fromBase58(fromOwner);
      } catch (_) {
        return TransactionResult.failure('Invalid sender address');
      }
      try {
        toPk = solana.Ed25519HDPublicKey.fromBase58(toOwner);
      } catch (_) {
        return TransactionResult.failure('Invalid recipient address');
      }
      if (fromOwner == toOwner) {
        return TransactionResult.failure('Cannot send to the same wallet');
      }

      final mintPk = solana.Ed25519HDPublicKey.fromBase58(usdcMint);

      // Derive ATAs
      final fromAta = await solana.findAssociatedTokenAddress(
        owner: fromPk,
        mint: mintPk,
      );
      final toAta = await solana.findAssociatedTokenAddress(
        owner: toPk,
        mint: mintPk,
      );

      // Convert amount → base units (USDC has 6 decimals)
      final amountBase = (amountUsdc * 1e6).round();

      // Check sender ATA exists & has sufficient balance
      final senderBalance = await _baseTxService.getUsdcBalance(fromOwner);
      if (senderBalance < amountUsdc) {
        return TransactionResult.failure(
          'Insufficient USDC balance (have ${senderBalance.toStringAsFixed(2)}, '
          'need ${amountUsdc.toStringAsFixed(2)})',
        );
      }

      // Check whether recipient ATA exists
      final recipientHasAta = await _solana.hasAssociatedTokenAccount(
        owner: toPk,
        mint: mintPk,
        commitment: solana.Commitment.confirmed,
      );

      _logger.info(
        'USDC transfer: $amountUsdc to $toOwner '
        '(recipient ATA exists: $recipientHasAta)',
        tag: 'UsdcTransfer',
      );

      // Build instructions
      final instructions = <Instruction>[];
      if (!recipientHasAta) {
        instructions.add(
          solana.AssociatedTokenAccountInstruction.createAccount(
            funder: fromPk,
            address: toAta,
            owner: toPk,
            mint: mintPk,
          ),
        );
      }
      instructions.add(
        solana.TokenInstruction.transferChecked(
          amount: amountBase,
          decimals: usdcDecimals,
          source: fromAta,
          mint: mintPk,
          destination: toAta,
          owner: fromPk,
        ),
      );

      // Compile message
      final blockhashResp = await _solana.rpcClient.getLatestBlockhash(
        commitment: solana.Commitment.confirmed,
      );
      final message = solana.Message(instructions: instructions);
      final compiled = message.compile(
        recentBlockhash: blockhashResp.value.blockhash,
        feePayer: fromPk,
      );
      final messageBytes = Uint8List.fromList(compiled.toByteArray().toList());

      // Sign via the user's wallet (Privy or MWA)
      final sigBytes = await _signMessage(messageBytes, fromOwner);

      // Assemble wire tx: compactU16(1) + 64-byte sig + message
      final builder = BytesBuilder();
      builder.add(_compactU16(1));
      builder.add(sigBytes);
      builder.add(messageBytes);
      final txBase64 = base64Encode(builder.toBytes());

      final txSig = await _solana.rpcClient.sendTransaction(
        txBase64,
        preflightCommitment: solana.Commitment.confirmed,
      );

      _logger.info('USDC transfer submitted: $txSig', tag: 'UsdcTransfer');
      return TransactionResult.success(txSig);
    } catch (error, stack) {
      _logger.error(
        'USDC transfer failed',
        error: error,
        stackTrace: stack,
        tag: 'UsdcTransfer',
      );
      return TransactionResult.failure(_humanError(error));
    }
  }

  Future<List<int>> _signMessage(
    Uint8List messageBytes,
    String authority,
  ) async {
    // Prefer MWA if currently connected to this address
    final isMwa = _mwaService.connectedPublicKey == authority;

    if (isMwa) {
      final result = await _mwaService.signMessage(base64Encode(messageBytes));
      if (!result.success || result.signature == null) {
        throw Exception('MWA signing failed: ${result.error ?? 'unknown'}');
      }
      return result.signature!.toList();
    }

    final wallet = await _privyWallet.getOrCreateWallet();
    if (wallet == null) {
      throw Exception('Privy wallet unavailable');
    }
    final sigBase64 = await _privyWallet.signTransaction(wallet, messageBytes);
    if (sigBase64 == null) {
      throw Exception('Privy signing failed');
    }
    return base64Decode(sigBase64).toList();
  }

  static List<int> _compactU16(int value) {
    if (value < 0x80) return [value];
    if (value < 0x4000) return [(value & 0x7f) | 0x80, value >> 7];
    return [(value & 0x7f) | 0x80, ((value >> 7) & 0x7f) | 0x80, value >> 14];
  }

  String _humanError(Object e) {
    final s = e.toString();
    if (s.contains('insufficient')) {
      return 'Insufficient SOL for transaction fee';
    }
    if (s.contains('blockhash')) {
      return 'Network busy — please try again';
    }
    return s.replaceFirst('Exception: ', '');
  }
}

final usdcTransferServiceProvider = Provider<UsdcTransferService>((ref) {
  return UsdcTransferService(
    logger: ref.watch(loggerServiceProvider),
    privyWallet: ref.watch(privyWalletManagerProvider),
    mwaService: ref.watch(mwaWalletServiceProvider),
    baseTxService: ref.watch(solanaTransactionServiceProvider),
  );
});
