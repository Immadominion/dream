import 'package:flutter_test/flutter_test.dart';

import 'package:dream/core/navigation/trade_share_link.dart';

void main() {
  test('builds canonical trade share URLs', () {
    const link = TradeShareLink(
      symbol: 'JTO-PERP',
      side: 'buy',
      leverage: 5,
    );

    expect(
      link.webUri.toString(),
      'https://dream.app/trade/JTO-PERP?side=buy&leverage=5',
    );
    expect(
      link.appUri.toString(),
      'dreamapp://trade/JTO-PERP?side=buy&leverage=5',
    );
  });

  test('parses custom-scheme and https trade share URLs', () {
    final appUri = Uri.parse('dreamapp://trade/JTO-PERP?side=long&leverage=7');
    final webUri = Uri.parse(
      'https://dream.app/trade/JTO-PERP?side=sell&leverage=3',
    );

    final parsedApp = TradeShareLink.parse(appUri);
    final parsedWeb = TradeShareLink.parse(webUri);

    expect(parsedApp, isNotNull);
    expect(parsedApp!.symbol, 'JTO-PERP');
    expect(parsedApp.side, 'buy');
    expect(parsedApp.leverage, 7);

    expect(parsedWeb, isNotNull);
    expect(parsedWeb!.symbol, 'JTO-PERP');
    expect(parsedWeb.side, 'sell');
    expect(parsedWeb.leverage, 3);
  });
}