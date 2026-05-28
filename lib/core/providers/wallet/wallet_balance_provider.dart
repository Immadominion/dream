import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/solana/solana_transaction_service.dart';

/// Fetches the wallet's on-chain USDC balance (mainnet) and auto-refreshes
/// every 10 seconds so the displayed balance stays current during a trading
/// session without requiring a manual pull-to-refresh.
///
/// Keyed by wallet address so it only runs for the connected wallet.
/// Returns [double] USDC amount (e.g., 100.5 means 100.50 USDC).
///
/// Usage:
/// ```dart
/// final usdc = ref.watch(walletUsdcBalanceProvider(walletAddress));
/// ```
final walletUsdcBalanceProvider = FutureProvider.autoDispose.family<double, String>(
  (ref, walletAddress) async {
    final service = ref.watch(solanaTransactionServiceProvider);

    // Keep the provider alive even when not watched (e.g. between tab switches)
    // so the timer fires while the user is on the Trade page.
    ref.keepAlive();

    // Schedule a self-invalidation every 10 s to re-fetch the on-chain balance.
    final timer = Timer.periodic(const Duration(seconds: 10), (_) {
      ref.invalidateSelf();
    });
    ref.onDispose(timer.cancel);

    return service.getUsdcBalance(walletAddress);
  },
);
