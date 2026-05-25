import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/trade_provider.dart';
import 'trade_page.dart';

// Full-screen market detail page shown above the main shell.
// This hides shell top/bottom bars and lets the trade header own back nav.
class MarketTradePage extends ConsumerStatefulWidget {
  final String symbol;

  const MarketTradePage({super.key, required this.symbol});

  @override
  ConsumerState<MarketTradePage> createState() => _MarketTradePageState();
}

class _MarketTradePageState extends ConsumerState<MarketTradePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tradeProvider.notifier).selectSymbol(widget.symbol);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TradePage(showBackButton: true, onBackPressed: () => context.pop());
  }
}
