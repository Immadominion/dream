import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/providers/phoenix/phoenix_auth_provider.dart';
import '../../../../core/providers/settings/ui_preferences_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../markets/providers/markets_provider.dart';
import '../../providers/trade_provider.dart';
import '../widgets/orderbook_widget.dart';
import '../widgets/price_chart_widget.dart';
import '../widgets/trade_compact_orderbook.dart';
import '../widgets/trade_form_widgets.dart';
import '../widgets/trade_market_header.dart';
import '../widgets/trade_order_panel.dart';
import '../widgets/trade_size_input.dart';
import '../widgets/trade_status_widgets.dart';
import '../widgets/trade_tp_sl_section.dart';

const double _kTabletBreakpoint = 768.0;

// ---------------------------------------------------------------------------
// Bybit-style perp trade page.
//   Phone — form on the left, compact ladder on the right.
//           Chart is hidden by default; toggle pill in header reveals it.
//   Tablet — chart + orderbook left column, full form right column.
// ---------------------------------------------------------------------------

class TradePage extends ConsumerWidget {
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const TradePage({super.key, this.showBackButton = false, this.onBackPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradeState = ref.watch(tradeProvider);
    final marketsState = ref.watch(marketsProvider);
    final phoenixAuth = ref.watch(phoenixAuthProvider);
    final isAuthed = phoenixAuth.isAuthenticated;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= _kTabletBreakpoint) {
              return _TabletLayout(
                tradeState: tradeState,
                marketsState: marketsState,
                isAuthed: isAuthed,
                showBackButton: showBackButton,
                onBackPressed: onBackPressed,
              );
            }
            return _PhoneLayout(
              tradeState: tradeState,
              marketsState: marketsState,
              isAuthed: isAuthed,
              showBackButton: showBackButton,
              onBackPressed: onBackPressed,
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phone — order form (62%) + compact ladder (38%) with optional chart on top
// ---------------------------------------------------------------------------

class _PhoneLayout extends ConsumerStatefulWidget {
  final TradeState tradeState;
  final MarketsState marketsState;
  final bool isAuthed;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const _PhoneLayout({
    required this.tradeState,
    required this.marketsState,
    required this.isAuthed,
    required this.showBackButton,
    required this.onBackPressed,
  });

  @override
  ConsumerState<_PhoneLayout> createState() => _PhoneLayoutState();
}

class _PhoneLayoutState extends ConsumerState<_PhoneLayout> {
  // Initialized from persisted pref in initState; falls back to true (show chart).
  bool _chartVisible = true;

  @override
  void initState() {
    super.initState();
    // Read persisted preference synchronously (SharedPreferences already loaded)
    _chartVisible = ref.read(uiPreferencesProvider).tradeChartVisible;
  }

  void _onChartToggle(bool v) {
    setState(() => _chartVisible = v);
    ref.read(uiPreferencesProvider.notifier).setTradeChartVisible(v);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TradeMarketHeader(
          tradeState: widget.tradeState,
          marketsState: widget.marketsState,
          showBackButton: widget.showBackButton,
          onBackPressed: widget.onBackPressed,
          chartVisible: _chartVisible,
          onChartToggle: _onChartToggle,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: _chartVisible
              ? PriceChartWidget(symbol: widget.tradeState.symbol, height: 220)
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 62,
                child: _OrderFormScroll(
                  tradeState: widget.tradeState,
                  isAuthed: widget.isAuthed,
                ),
              ),
              SizedBox(
                width: 155.w,
                child: TradeCompactOrderbook(symbol: widget.tradeState.symbol),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tablet — left: chart + orderbook · right: order form
// ---------------------------------------------------------------------------

class _TabletLayout extends StatelessWidget {
  final TradeState tradeState;
  final MarketsState marketsState;
  final bool isAuthed;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const _TabletLayout({
    required this.tradeState,
    required this.marketsState,
    required this.isAuthed,
    required this.showBackButton,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TradeMarketHeader(
          tradeState: tradeState,
          marketsState: marketsState,
          showBackButton: showBackButton,
          onBackPressed: onBackPressed,
          chartVisible: true,
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    PriceChartWidget(symbol: tradeState.symbol, height: 340),
                    Expanded(child: OrderbookWidget(symbol: tradeState.symbol)),
                  ],
                ),
              ),
              Container(
                width: 1,
                color: AppColors.borderDark.withValues(alpha: 0.4),
              ),
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
      padding: EdgeInsets.fromLTRB(
        14.w,
        12.h,
        12.w,
        MediaQuery.paddingOf(context).bottom + 24.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TradeActivePositionStrip(symbol: tradeState.symbol),
          // Order type inline with side toggle — same row, Bybit-style
          Row(
            children: [
              TradeOrderTypeToggle(tradeState: tradeState),
              SizedBox(width: 12.w),
              Expanded(child: TradeSideToggle(tradeState: tradeState)),
            ],
          ),
          SizedBox(height: 12.h),
          if (tradeState.orderType == OrderType.limit) ...[
            TradePriceInput(tradeState: tradeState),
            SizedBox(height: 10.h),
          ],
          TradeSizeInput(tradeState: tradeState),
          SizedBox(height: 14.h),
          TradeLeverageSelector(tradeState: tradeState),
          SizedBox(height: 14.h),
          TradeTpSlSection(tradeState: tradeState),
          SizedBox(height: 10.h),
          if (tradeState.orderType == OrderType.limit)
            TradePostOnlyToggle(tradeState: tradeState),
          if (tradeState.orderType == OrderType.market) ...[
            TradeSlippageSelector(tradeState: tradeState),
          ],
          SizedBox(height: 14.h),
          TradeOrderSummary(tradeState: tradeState),
          SizedBox(height: 16.h),
          TradeSubmitButton(tradeState: tradeState, isAuthed: isAuthed),
          if (tradeState.submitError != null) ...[
            SizedBox(height: 12.h),
            TradeErrorBanner(error: tradeState.submitError!),
          ],
          if (tradeState.lastTxSignature != null) ...[
            SizedBox(height: 12.h),
            TradeSuccessBanner(txSig: tradeState.lastTxSignature!),
          ],
          SizedBox(height: 12.h),
        ],
      ),
    );
  }
}
