import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/solana/wallet_name_service.dart';

/// Resolves a Solana wallet address to its primary human-readable domain name.
///
/// Covers all major Solana TLDs (.skr, .sol, .abc, .bonk, .backpack, …) via
/// the Helius Names API. The result is cached per address for the lifetime of
/// the [ProviderScope].
///
/// **Usage:**
/// ```dart
/// final nameAsync = ref.watch(walletNameProvider(walletAddress));
/// final name = nameAsync.valueOrNull; // null while loading or not found
/// ```
final walletNameProvider = FutureProvider.family<String?, String>(
  (ref, walletAddress) => WalletNameService.resolveWalletName(walletAddress),
);
