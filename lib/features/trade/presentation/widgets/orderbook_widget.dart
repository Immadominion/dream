import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/models/phoenix/phoenix_models.dart';
import '../../../../core/services/phoenix/phoenix_websocket_service.dart';
import '../../../../core/theme/app_colors.dart';
import 'orderbook_tabs.dart';

// ---------------------------------------------------------------------------
// Orderbook Provider
// ---------------------------------------------------------------------------

class OrderbookState {
  final PhoenixOrderbook? orderbook;
  final List<PhoenixRecentTrade> recentTrades;

  const OrderbookState({this.orderbook, this.recentTrades = const []});

  OrderbookState copyWith({
    PhoenixOrderbook? orderbook,
    List<PhoenixRecentTrade>? recentTrades,
  }) => OrderbookState(
    orderbook: orderbook ?? this.orderbook,
    recentTrades: recentTrades ?? this.recentTrades,
  );
}

class OrderbookNotifier extends Notifier<OrderbookState> {
  StreamSubscription<OrderbookMessage>? _obSub;
  StreamSubscription<RecentTradesMessage>? _tradesSub;
  final String _symbol;

  OrderbookNotifier(this._symbol);

  @override
  OrderbookState build() {
    ref.onDispose(_dispose);
    Future.microtask(() => _subscribe(_symbol));
    return const OrderbookState();
  }

  void _subscribe(String symbol) {
    final ws = ref.read(phoenixWebSocketServiceProvider);

    ws.subscribeOrderbook(symbol);
    _obSub = ws.orderbookStream
        .where((m) => m.orderbook.symbol == symbol)
        .listen((m) {
          state = state.copyWith(orderbook: m.orderbook);
        });

    ws.subscribeTrades(symbol);
    _tradesSub = ws.tradesStream.where((m) => m.symbol == symbol).listen((m) {
      final updated = [...m.trades, ...state.recentTrades];
      state = state.copyWith(recentTrades: updated.take(30).toList());
    });
  }

  void _dispose() {
    _obSub?.cancel();
    _tradesSub?.cancel();
    final ws = ref.read(phoenixWebSocketServiceProvider);
    ws.unsubscribeOrderbook(_symbol);
    ws.unsubscribeTrades(_symbol);
  }
}

final orderbookProvider =
    NotifierProvider.family<OrderbookNotifier, OrderbookState, String>(
      (symbol) => OrderbookNotifier(symbol),
    );

// ---------------------------------------------------------------------------
// Orderbook + Trades Widget
// ---------------------------------------------------------------------------

class OrderbookWidget extends ConsumerStatefulWidget {
  final String symbol;

  const OrderbookWidget({super.key, required this.symbol});

  @override
  ConsumerState<OrderbookWidget> createState() => _OrderbookWidgetState();
}

class _OrderbookWidgetState extends ConsumerState<OrderbookWidget>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar
        TabBar(
          controller: _tab,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: AppColors.textPrimaryDark,
          unselectedLabelColor: AppColors.textMutedDark,
          labelStyle: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w400,
          ),
          dividerColor: AppColors.borderDark,
          tabs: const [
            Tab(text: 'Depth'),
            Tab(text: 'Trades'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              OrderbookDepthTab(symbol: widget.symbol),
              OrderbookTradesTab(symbol: widget.symbol),
            ],
          ),
        ),
      ],
    );
  }
}
