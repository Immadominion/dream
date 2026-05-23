import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/phoenix/phoenix_models.dart';
import '../../positions/providers/positions_provider.dart';

// The account page is a read-only view of the trader's equity summary.
// It re-uses the same traderState data that positionsProvider already fetches,
// so this provider is a simple selector to avoid redundant requests.

class AccountState {
  final PhoenixTraderState? traderState;
  final bool isLoading;
  final String? error;

  const AccountState({this.traderState, this.isLoading = false, this.error});

  double get equity => traderState?.equity ?? 0;
  double get collateral => traderState?.collateral ?? 0;
  double get availableMargin => traderState?.availableMargin ?? 0;
  double get unrealizedPnl => traderState?.unrealizedPnl ?? 0;
  int get riskTier => traderState?.riskTier ?? 0;

  String get riskTierLabel => switch (riskTier) {
    0 => 'Safe',
    1 => 'At Risk',
    2 => 'Cancellable',
    3 => 'Liquidatable',
    _ => 'High Risk',
  };
}

class AccountNotifier extends Notifier<AccountState> {
  @override
  AccountState build() {
    // React to positionsProvider changes
    final posState = ref.watch(positionsProvider);
    return AccountState(
      traderState: posState.traderState,
      isLoading: posState.isLoading,
      error: posState.error,
    );
  }

  Future<void> refresh() => ref.read(positionsProvider.notifier).refresh();
}

final accountProvider = NotifierProvider<AccountNotifier, AccountState>(
  AccountNotifier.new,
);
