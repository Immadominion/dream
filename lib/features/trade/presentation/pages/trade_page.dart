import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/providers/phoenix/phoenix_auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../markets/providers/markets_provider.dart';
import '../../providers/trade_provider.dart';
import '../widgets/orderbook_widget.dart';
import '../widgets/price_chart_widget.dart';
import '../widgets/trade_form_widgets.dart';
import '../widgets/trade_size_input.dart';
import '../widgets/trade_market_header.dart';
import '../widgets/trade_order_panel.dart';
import '../widgets/trade_status_widgets.dart';
import '../widgets/trade_tp_sl_section.dart';

// Width threshold above which a two-column iPad layout is used.
const double _kTabletBreakpoint = 768.0;

class TradePage extends ConsumerWidget {
  const TradePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradeState = ref.watch(tradeProvider);
    final marketsState = ref.watch(marketsProvider);
    final phoenixAuth = ref.watch(phoenixAuthProvider);
    final isAuthed = phoenixAuth.isAuthenticated;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= _kTabletBreakpoint) {
              return _TabletLayout(
                tradeState: tradeState,
                marketsState: marketsState,
                isAuthed: isAuthed,
              );
            }
            return _PhoneLayout(
              tradeState: tradeState,
              marketsState: marketsState,
              isAuthed: isAuthed,
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phone layout — stacked single column with Trade / Depth tabs
// ---------------------------------------------------------------------------

class _PhoneLayout extends StatelessWidget {
  final TradeState tradeState;
  final MarketsState marketsState;
  final bool isAuthed;

  const _PhoneLayout({
    required this.tradeState,
    required this.marketsState,
    required this.isAuthed,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TradeMarketHeader(tradeState: tradeState, marketsState: marketsState),
          PriceChartWidget(symbol: tradeState.symbol, height: 210),
          Container(
            color: AppColors.surfaceDark,
            child: TabBar(
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: AppColors.textPrimaryDark,
              unselectedLabelColor: AppColors.textMutedDark,
              labelStyle: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w400,
              ),
              dividerColor: AppColors.borderDark,
              tabs: const [
                Tab(text: 'Trade'),
                Tab(text: 'Depth'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _OrderFormScroll(tradeState: tradeState, isAuthed: isAuthed),
                OrderbookWidget(symbol: tradeState.symbol),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tablet / iPad layout — chart + orderbook on left, order form on right
// ---------------------------------------------------------------------------

class _TabletLayout extends StatelessWidget {
  final TradeState tradeState;
  final MarketsState marketsState;
  final bool isAuthed;

  const _TabletLayout({
    required this.tradeState,
    required this.marketsState,
    required this.isAuthed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TradeMarketHeader(tradeState: tradeState, marketsState: marketsState),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column: chart + orderbook
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    PriceChartWidget(symbol: tradeState.symbol, height: 340),
                    Expanded(child: OrderbookWidget(symbol: tradeState.symbol)),
                  ],
                ),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.borderDark,
              ),
              // Right column: scrollable order form
              SizedBox(
                width: 340,
                child: _OrderFormScroll(
                  tradeState: tradeState,
                  isAuthed: isAuthed,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Scrollable order form — shared between phone and tablet layouts
// ---------------------------------------------------------------------------

class _OrderFormScroll extends StatelessWidget {
  final TradeState tradeState;
  final bool isAuthed;

  const _OrderFormScroll({required this.tradeState, required this.isAuthed});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          TradeActivePositionStrip(symbol: tradeState.symbol),
          TradeSideToggle(tradeState: tradeState),
          SizedBox(height: 12.h),
          TradeOrderTypeToggle(tradeState: tradeState),
          SizedBox(height: 16.h),
          if (tradeState.orderType == OrderType.limit) ...[
            TradePriceInput(tradeState: tradeState),
            SizedBox(height: 10.h),
            TradePostOnlyToggle(tradeState: tradeState),
            SizedBox(height: 12.h),
          ],
          TradeSizeInput(tradeState: tradeState),
          SizedBox(height: 12.h),
          TradeLeverageSelector(tradeState: tradeState),
          SizedBox(height: 16.h),
          TradeTpSlSection(tradeState: tradeState),
          SizedBox(height: 20.h),
          if (tradeState.orderType == OrderType.market) ...[
            TradeSlippageSelector(tradeState: tradeState),
            SizedBox(height: 12.h),
          ],
          TradeOrderSummary(tradeState: tradeState),
          SizedBox(height: 20.h),
          TradeSubmitButton(tradeState: tradeState, isAuthed: isAuthed),
          if (tradeState.submitError != null) ...[
            SizedBox(height: 12.h),
            TradeErrorBanner(error: tradeState.submitError!),
          ],
          if (tradeState.lastTxSignature != null) ...[
            SizedBox(height: 12.h),
            TradeSuccessBanner(txSig: tradeState.lastTxSignature!),
          ],
          SizedBox(height: 16.h),
        ],
      ),
    );
  }
}
