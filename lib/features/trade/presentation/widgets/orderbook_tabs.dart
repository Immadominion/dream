import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/models/phoenix/phoenix_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import 'orderbook_widget.dart';

// ---------------------------------------------------------------------------
// Compact price formatter (internal to this file)
// ---------------------------------------------------------------------------

String _obPrice(double price) {
  if (price >= 10000) return addThousandsSep(price.toStringAsFixed(0));
  if (price >= 1000) {
    final parts = price.toStringAsFixed(1).split('.');
    return '${addThousandsSep(parts[0])}.${parts[1]}';
  }
  if (price >= 100) return price.toStringAsFixed(2);
  return price.toStringAsFixed(3);
}

// ---------------------------------------------------------------------------
// Orderbook Depth Tab
// ---------------------------------------------------------------------------

class OrderbookDepthTab extends ConsumerWidget {
  final String symbol;
  const OrderbookDepthTab({super.key, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(orderbookProvider(symbol));
    final ob = state.orderbook;

    if (ob == null) {
      return Center(
        child: Text(
          'Connecting…',
          style: TextStyle(color: AppColors.textMutedDark, fontSize: 12.sp),
        ),
      );
    }

    final asks = ob.asks.take(10).toList().reversed.toList();
    final bids = ob.bids.take(10).toList();

    final maxSize = [
      ...ob.asks.take(10).map((e) => e.size),
      ...ob.bids.take(10).map((e) => e.size),
    ].fold(0.0, (a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + 24.h,
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Price (USDC)',
                    style: TextStyle(
                      color: AppColors.textMutedDark,
                      fontSize: 10.sp,
                    ),
                  ),
                ),
                Text(
                  'Size',
                  style: TextStyle(
                    color: AppColors.textMutedDark,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
          ...asks.map(
            (level) =>
                OrderbookLevel(level: level, isBid: false, maxSize: maxSize),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            child: Row(
              children: [
                Text(
                  _obPrice(ob.mid ?? ob.bestBid),
                  style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  'Spread ${ob.spreadPct.toStringAsFixed(3)}%',
                  style: TextStyle(
                    color: AppColors.textMutedDark,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
          ...bids.map(
            (level) =>
                OrderbookLevel(level: level, isBid: true, maxSize: maxSize),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single depth level row
// ---------------------------------------------------------------------------

class OrderbookLevel extends StatelessWidget {
  final PhoenixOrderLevel level;
  final bool isBid;
  final double maxSize;

  const OrderbookLevel({
    super.key,
    required this.level,
    required this.isBid,
    required this.maxSize,
  });

  @override
  Widget build(BuildContext context) {
    final color = isBid ? AppColors.bullish : AppColors.bearish;
    final pct = maxSize > 0 ? (level.size / maxSize).clamp(0.0, 1.0) : 0.0;
    final priceStr = _obPrice(level.price);
    final sizeStr = _formatSize(level.size);

    return SizedBox(
      height: 20.h,
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: isBid ? Alignment.centerLeft : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: pct,
                child: Container(color: color.withAlpha(25)),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    priceStr,
                    style: TextStyle(
                      color: color,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  sizeStr,
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(double size) {
    if (size >= 1000) return '${(size / 1000).toStringAsFixed(1)}K';
    if (size >= 100) return size.toStringAsFixed(1);
    return size.toStringAsFixed(3);
  }
}

// ---------------------------------------------------------------------------
// Recent Trades Tab
// ---------------------------------------------------------------------------

class OrderbookTradesTab extends ConsumerWidget {
  final String symbol;
  const OrderbookTradesTab({super.key, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(orderbookProvider(symbol));
    final trades = state.recentTrades;

    if (trades.isEmpty) {
      return Center(
        child: Text(
          'Waiting for trades…',
          style: TextStyle(color: AppColors.textMutedDark, fontSize: 12.sp),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          child: Row(
            children: [
              SizedBox(
                width: 80.w,
                child: Text(
                  'Price',
                  style: TextStyle(
                    color: AppColors.textMutedDark,
                    fontSize: 10.sp,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Size',
                  style: TextStyle(
                    color: AppColors.textMutedDark,
                    fontSize: 10.sp,
                  ),
                ),
              ),
              Text(
                'Time',
                style: TextStyle(
                  color: AppColors.textMutedDark,
                  fontSize: 10.sp,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 24.h,
            ),
            itemCount: trades.length,
            itemBuilder: (_, i) => OrderbookTradeTile(trade: trades[i]),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Single recent-trade row
// ---------------------------------------------------------------------------

class OrderbookTradeTile extends StatelessWidget {
  final PhoenixRecentTrade trade;
  const OrderbookTradeTile({super.key, required this.trade});

  @override
  Widget build(BuildContext context) {
    final color = trade.isBuy ? AppColors.bullish : AppColors.bearish;
    final priceStr = _obPrice(trade.price);
    final sizeStr = trade.size.toStringAsFixed(3);
    final dt = DateTime.fromMillisecondsSinceEpoch(
      trade.timestamp > 9999999999 ? trade.timestamp : trade.timestamp * 1000,
      isUtc: true,
    );
    final timeStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

    return SizedBox(
      height: 20.h,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Row(
          children: [
            SizedBox(
              width: 80.w,
              child: Text(
                priceStr,
                style: TextStyle(
                  color: color,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Text(
                sizeStr,
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 11.sp,
                ),
              ),
            ),
            Text(
              timeStr,
              style: TextStyle(color: AppColors.textMutedDark, fontSize: 10.sp),
            ),
          ],
        ),
      ),
    );
  }
}
