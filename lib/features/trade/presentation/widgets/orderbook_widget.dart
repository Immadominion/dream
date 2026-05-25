import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/models/phoenix/phoenix_models.dart';
import '../../../../core/services/phoenix/phoenix_websocket_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
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
    final state = ref.watch(orderbookProvider(widget.symbol));
    final ob = state.orderbook;

    return Column(
      children: [
        if (ob != null)
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 4.h),
            child: Row(
              children: [
                Expanded(
                  child: _OrderbookHeadlineMetric(
                    label: 'Bid',
                    value: _headlinePrice(ob.bestBid),
                    valueColor: AppColors.bullish,
                  ),
                ),
                Expanded(
                  child: _OrderbookHeadlineMetric(
                    label: 'Ask',
                    value: _headlinePrice(ob.bestAsk),
                    valueColor: AppColors.bearish,
                  ),
                ),
                Expanded(
                  child: _OrderbookHeadlineMetric(
                    label: 'Mid',
                    value: _headlinePrice(
                      ob.mid ?? ((ob.bestBid + ob.bestAsk) / 2),
                    ),
                  ),
                ),
                Expanded(
                  child: _OrderbookHeadlineMetric(
                    label: 'Spread',
                    value: '${ob.spreadPct.toStringAsFixed(3)}%',
                  ),
                ),
              ],
            ),
          ),
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
          labelPadding: EdgeInsets.symmetric(horizontal: 12.w),
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

String _headlinePrice(double price) {
  if (price >= 10000) return addThousandsSep(price.toStringAsFixed(0));
  if (price >= 1000) {
    final parts = price.toStringAsFixed(1).split('.');
    return '${addThousandsSep(parts[0])}.${parts[1]}';
  }
  if (price >= 100) return price.toStringAsFixed(2);
  return price.toStringAsFixed(3);
}

class _OrderbookHeadlineMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _OrderbookHeadlineMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textMutedDark, fontSize: 9.sp),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimaryDark,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
