import 'package:flutter_test/flutter_test.dart';

import 'package:dream/core/models/phoenix/phoenix_trader_models.dart';

void main() {
  test('parses Phoenix amount objects from trader state payloads', () {
    final state = PhoenixTraderState.fromApiJson({
      'collateralBalance': {
        'value': 3000000,
        'decimals': 6,
        'ui': '3.000000',
      },
      'effectiveCollateral': {
        'value': 3000000,
        'decimals': 6,
        'ui': '3.000000',
      },
      'initialMargin': {
        'value': 0,
        'decimals': 6,
        'ui': '0.000000',
      },
      'portfolioValue': {
        'value': 3000000,
        'decimals': 6,
        'ui': '3.000000',
      },
      'unrealizedPnl': {
        'value': 0,
        'decimals': 6,
        'ui': '0.000000',
      },
      'riskTier': 'safe',
      'positions': const [],
      'limitOrders': const {},
    }, 'wallet');

    expect(state.collateral, 3.0);
    expect(state.availableMargin, 3.0);
    expect(state.equity, 3.0);
  });
}