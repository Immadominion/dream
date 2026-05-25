import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/models/phoenix/phoenix_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import 'orderbook_widget.dart';

String _obPrice(double price) {
  if (price >= 10000) return addThousandsSep(price.toStringAsFixed(0));
  if (price >= 1000) {
    final parts = price.toStringAsFixed(1).split('.');
    return '${addThousandsSep(parts[0])}.${parts[1]}';
  }
  if (price >= 100) return price.toStringAsFixed(2);
  return price.toStringAsFixed(3);
}

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

    final asks = ob.asks.take(12).toList();
    final bids = ob.bids.take(12).toList();
    final rowCount = math.max(asks.length, bids.length);
    final maxSize = [
      ...asks.map((level) => level.size),
      ...bids.map((level) => level.size),
    ].fold(0.0, (a, b) => a > b ? a : b);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Bid Qty',
                      style: TextStyle(
                        color: AppColors.textMutedDark,
                        fontSize: 10.sp,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Bid',
                      style: TextStyle(
                        color: AppColors.textMutedDark,
                        fontSize: 10.sp,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Ask',
                      style: TextStyle(
                        color: AppColors.textMutedDark,
                        fontSize: 10.sp,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Ask Qty',
                      style: TextStyle(
                        color: AppColors.textMutedDark,
                        fontSize: 10.sp,
                      ),
                    ),
                  ],
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
            itemCount: rowCount,
            itemBuilder: (_, index) => _OrderbookPairRow(
              bid: index < bids.length ? bids[index] : null,
              ask: index < asks.length ? asks[index] : null,
              maxSize: maxSize,
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderbookPairRow extends StatelessWidget {
  final PhoenixOrderLevel? bid;
  final PhoenixOrderLevel? ask;
  final double maxSize;

  const _OrderbookPairRow({
    required this.bid,
    required this.ask,
    required this.maxSize,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22.h,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Row(
          children: [
            Expanded(
              child: _OrderbookSideHalf(
                level: bid,
                maxSize: maxSize,
                isBid: true,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _OrderbookSideHalf(
                level: ask,
                maxSize: maxSize,
                isBid: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderbookSideHalf extends StatelessWidget {
  final PhoenixOrderLevel? level;
  final double maxSize;
  final bool isBid;

  const _OrderbookSideHalf({
    required this.level,
    required this.maxSize,
    required this.isBid,
  });

  @override
  Widget build(BuildContext context) {
    final color = isBid ? AppColors.bullish : AppColors.bearish;
    final pct = level == null || maxSize <= 0
        ? 0.0
        : (level!.size / maxSize).clamp(0.0, 1.0);

    return Stack(
      children: [
        Positioned.fill(
          child: Align(
            alignment: isBid ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: pct,
              child: Container(color: color.withAlpha(22)),
            ),
          ),
        ),
        Row(
          children: isBid
              ? [
                  Text(
                    _formatDepthSize(level?.size),
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 11.sp,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    level == null ? '--' : _obPrice(level!.price),
                    style: TextStyle(
                      color: color,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]
              : [
                  Text(
                    level == null ? '--' : _obPrice(level!.price),
                    style: TextStyle(
                      color: color,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDepthSize(level?.size),
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
        ),
      ],
    );
  }
}

String _formatDepthSize(double? size) {
  if (size == null || size <= 0) return '--';
  if (size >= 1000) return '${(size / 1000).toStringAsFixed(1)}K';
  if (size >= 100) return size.toStringAsFixed(1);
  return size.toStringAsFixed(3);
}

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
                width: 58.w,
                child: Text(
                  'Time',
                  style: TextStyle(
                    color: AppColors.textMutedDark,
                    fontSize: 10.sp,
                  ),
                ),
              ),
              SizedBox(
                width: 42.w,
                child: Text(
                  'Side',
                  style: TextStyle(
                    color: AppColors.textMutedDark,
                    fontSize: 10.sp,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Price',
                  style: TextStyle(
                    color: AppColors.textMutedDark,
                    fontSize: 10.sp,
                  ),
                ),
              ),
              SizedBox(
                width: 70.w,
                child: Text(
                  'Qty',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AppColors.textMutedDark,
                    fontSize: 10.sp,
                  ),
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

class OrderbookTradeTile extends StatelessWidget {
  final PhoenixRecentTrade trade;
  const OrderbookTradeTile({super.key, required this.trade});

  @override
  Widget build(BuildContext context) {
    final color = trade.isBuy ? AppColors.bullish : AppColors.bearish;
    final sideLabel = trade.isBuy ? 'Buy' : 'Sell';
    final priceStr = _obPrice(trade.price);
    final sizeStr = trade.size >= 100
        ? trade.size.toStringAsFixed(2)
        : trade.size.toStringAsFixed(4);
    final dt = DateTime.fromMillisecondsSinceEpoch(
      trade.timestamp > 9999999999 ? trade.timestamp : trade.timestamp * 1000,
      isUtc: true,
    ).toLocal();
    final timeStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

    return SizedBox(
      height: 24.h,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Row(
          children: [
            SizedBox(
              width: 58.w,
              child: Text(
                timeStr,
                style: TextStyle(
                  color: AppColors.textMutedDark,
                  fontSize: 10.sp,
                ),
              ),
            ),
            SizedBox(
              width: 42.w,
              child: Text(
                sideLabel,
                style: TextStyle(
                  color: color,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
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
            SizedBox(
              width: 70.w,
              child: Text(
                sizeStr,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 11.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
