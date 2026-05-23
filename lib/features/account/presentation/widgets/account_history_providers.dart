import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/phoenix/phoenix_models.dart';
import '../../../../core/services/phoenix/phoenix_trader_service.dart';

/// Trade fill history for a trader authority (last 50 fills).
final accountTradeHistoryProvider =
    FutureProvider.family<List<PhoenixTradeHistoryItem>, String>((
      ref,
      authority,
    ) async {
      final svc = ref.read(phoenixTraderServiceProvider);
      return svc.fetchTradeHistory(authority, limit: 50);
    });

/// Funding payment history for a trader authority (last 50 payments).
final accountFundingHistoryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      authority,
    ) async {
      final svc = ref.read(phoenixTraderServiceProvider);
      return svc.fetchFundingHistory(authority, limit: 50);
    });

/// Deposit / withdrawal history for a trader authority (last 50 events).
final accountCollateralHistoryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      authority,
    ) async {
      final svc = ref.read(phoenixTraderServiceProvider);
      return svc.fetchCollateralHistory(authority, limit: 50);
    });

/// Limit / market order history for a trader authority (last 50 orders).
final accountOrderHistoryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      authority,
    ) async {
      final svc = ref.read(phoenixTraderServiceProvider);
      return svc.fetchOrderHistory(authority, limit: 50);
    });
