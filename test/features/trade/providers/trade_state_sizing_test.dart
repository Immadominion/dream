import 'package:flutter_test/flutter_test.dart';

import 'package:dream/features/trade/providers/trade_state.dart';

void main() {
  test('isolated sizing leaves headroom below exact leverage max', () {
    const collateralUsdc = 1.0;
    const leverage = 5.0;
    const markPrice = 0.541;

    final qty = tradeBaseQuantity(
      collateralUsdc: collateralUsdc,
      leverage: leverage,
      markPrice: markPrice,
      takerFeeRateBps: 5.0,
      slippageBps: 50,
    );

    final exactQty = (collateralUsdc * leverage) / markPrice;

    expect(qty, greaterThan(0));
    expect(qty, lessThan(exactQty));
  });
}