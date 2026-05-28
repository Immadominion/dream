import 'package:flutter_test/flutter_test.dart';

import 'package:dream/core/models/phoenix/phoenix_models.dart';
import 'package:dream/core/services/phoenix/phoenix_trader_service.dart';

void main() {
  test('selects the primary cross trader account before isolated accounts', () {
    final trader = selectPrimaryCrossTraderView([
      {
        'traderPdaIndex': 0,
        'traderSubaccountIndex': 2,
        'collateralBalance': {'ui': '1.500000'},
      },
      {
        'traderPdaIndex': 0,
        'traderSubaccountIndex': 0,
        'collateralBalance': {'ui': '4.000000'},
      },
    ]);

    expect(trader['traderPdaIndex'], 0);
    expect(trader['traderSubaccountIndex'], 0);
    expect(
      (trader['collateralBalance'] as Map<String, dynamic>)['ui'],
      '4.000000',
    );
  });

  test('merges isolated positions and orders into the primary trader view', () {
    final merged = mergeTraderViews(
      primaryTraderView: {
        'traderPdaIndex': 0,
        'traderSubaccountIndex': 0,
        'collateralBalance': {'ui': '4.000000'},
        'effectiveCollateral': {'ui': '4.000000'},
        'initialMargin': {'ui': '0.000000'},
        'unrealizedPnl': {'ui': '0.100000'},
        'positions': const [],
        'limitOrders': const {},
      },
      traders: [
        {
          'traderPdaIndex': 0,
          'traderSubaccountIndex': 1,
          'unrealizedPnl': {'ui': '0.250000'},
          'positions': [
            {
              'symbol': 'JTO-PERP',
              'positionSize': 8.9,
              'entryPrice': 0.54,
              'markPrice': 0.53,
              'liquidationPrice': 0.48,
              'positionValue': 4.81,
              'positionInitialMargin': 1.2,
              'accumulatedFunding': 0,
            },
          ],
          'limitOrders': {
            'JTO-PERP': [
              {
                'side': 'bid',
                'price': 0.52,
                'initialTradeSize': 1,
                'tradeSizeRemaining': 1,
              },
            ],
          },
        },
        {
          'traderPdaIndex': 0,
          'traderSubaccountIndex': 0,
          'collateralBalance': {'ui': '4.000000'},
          'effectiveCollateral': {'ui': '4.000000'},
          'initialMargin': {'ui': '0.000000'},
          'unrealizedPnl': {'ui': '0.100000'},
          'positions': const [],
          'limitOrders': const {},
        },
      ],
    );

    final traderState = PhoenixTraderState.fromApiJson(
      merged,
      'wallet-authority',
    );

    expect(traderState.collateral, 4.0);
    expect(traderState.positions, hasLength(1));
    expect(traderState.positions.first.symbol, 'JTO-PERP');
    expect(traderState.openOrders, hasLength(1));
    expect(traderState.unrealizedPnl, closeTo(0.35, 0.000001));
  });

  test(
    'extracts wrapped Phoenix history payloads from data and events keys',
    () {
      expect(
        extractPhoenixHistoryRows({
          'data': [
            {'kind': 'trade'},
          ],
        }),
        [
          {'kind': 'trade'},
        ],
      );

      expect(
        extractPhoenixHistoryRows({
          'events': [
            {'kind': 'funding'},
          ],
        }),
        [
          {'kind': 'funding'},
        ],
      );
    },
  );

  test('parses live-style trade history rows from Phoenix', () {
    final trade = PhoenixTradeHistoryItem.fromJson({
      'marketSymbol': 'JTO',
      'instructionType': 'PlaceMarketOrder',
      'baseLotsBefore': '0',
      'baseLotsAfter': '8.9',
      'baseLotsDelta': '8.9',
      'virtualQuoteLotsDelta': '-4.84338',
      'realizedPnl': '0',
      'fees': '0.001526',
      'timestamp': '2026-05-27T23:14:12Z',
    });

    expect(trade.symbol, 'JTO-PERP');
    expect(trade.side, 'bid');
    expect(trade.size, closeTo(8.9, 0.000001));
    expect(trade.price, closeTo(0.5442, 0.0001));
    expect(trade.fee, closeTo(0.001526, 0.000001));
    expect(trade.instructionType, 'PlaceMarketOrder');
    expect(trade.isOpeningFill, isTrue);
    expect(trade.lifecycleLabel, 'Opened');
    expect(trade.lifecycleSideLabel, 'Long');
    expect(trade.timestamp, 1779923652000);
  });

  test('classifies ExecuteStopLoss as a close instead of a new short', () {
    final trade = PhoenixTradeHistoryItem.fromJson({
      'marketSymbol': 'JTO',
      'instructionType': 'ExecuteStopLoss',
      'baseLotsBefore': '8.9',
      'baseLotsAfter': '0',
      'baseLotsDelta': '-8.9',
      'price': '0.5261',
      'realizedPnl': '-0.16109',
      'fees': '0',
      'timestamp': '2026-05-28T05:17:28Z',
    });

    expect(trade.isClosingFill, isTrue);
    expect(trade.isStopLossExecution, isTrue);
    expect(trade.lifecycleSideLabel, 'Long');
    expect(trade.lifecycleLabel, 'Stop Loss');
    expect(trade.realizedPnl, closeTo(-0.16109, 0.000001));
  });
}
