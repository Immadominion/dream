import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../positions/providers/positions_provider.dart';
import '../../providers/trade_provider.dart';
import 'trade_receipt_sheet.dart';
import '../../../../core/theme/dream_colors.dart';

// ---------------------------------------------------------------------------
// Active position strip — shown when user already has a position open
// ---------------------------------------------------------------------------

class TradeActivePositionStrip extends ConsumerWidget {
  final String symbol;
  final TradeSubmittedTrade? lastSubmittedTrade;
  const TradeActivePositionStrip({
    super.key,
    required this.symbol,
    this.lastSubmittedTrade,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positions = ref.watch(positionsProvider).positions;
    final position = positions.where((p) => p.symbol == symbol).firstOrNull;

    if (position == null) return const SizedBox.shrink();

    final isLong = position.side.toLowerCase() == 'long';
    final sideColor = isLong ? AppColors.bullish : AppColors.bearish;
    final sideLabel = isLong ? 'LONG' : 'SHORT';
    final pnl = position.unrealizedPnl;
    final pnlColor = pnl >= 0 ? AppColors.bullish : AppColors.bearish;
    final baseSymbol = symbol.split('-').first;
    final shareTrade =
        lastSubmittedTrade ?? TradeSubmittedTrade.fromPosition(position);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: sideColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: sideColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Text(
              sideLabel,
              style: TextStyle(
                color: sideColor,
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            '${position.sizeBase.toStringAsFixed(4)} $baseSymbol',
            style: TextStyle(
              color: context.dreamColors.onSurface,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 4.w),
          Text(
            '@ ${formatPrice(position.entryPrice)}',
            style: TextStyle(
              color: context.dreamColors.muted,
              fontSize: 11.sp,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => TradeReceiptSheet.show(
              context,
              trade: shareTrade,
              position: position,
            ),
            child: Container(
              width: 32.w,
              height: 32.w,
              margin: EdgeInsets.only(right: 8.w),
              decoration: BoxDecoration(
                color: context.dreamColors.onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                Icons.ios_share_rounded,
                color: context.dreamColors.onSurface,
                size: 16.sp,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatPnl(pnl),
                style: TextStyle(
                  color: pnlColor,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                position.isProfitable ? 'Shareable P&L' : 'Open position',
                style: TextStyle(
                  color: context.dreamColors.mutedSecondary,
                  fontSize: 9.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error banner
// ---------------------------------------------------------------------------

class TradeErrorBanner extends StatelessWidget {
  final String error;
  const TradeErrorBanner({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.bearish.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.bearish, size: 16.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: AppColors.bearish, fontSize: 12.sp),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plain submission status line shown after a trade is submitted.
// ---------------------------------------------------------------------------

class TradeSubmissionStatusText extends StatelessWidget {
  final TradeSubmittedTrade trade;

  const TradeSubmissionStatusText({super.key, required this.trade});

  @override
  Widget build(BuildContext context) {
    final baseSymbol = trade.symbol.split('-').first;
    final sideLabel = trade.side == OrderSide.buy ? 'Long' : 'Short';

    return Text(
      '$sideLabel $baseSymbol order placed · ${_formatTradeSubmissionTime(trade.submittedAt)}',
      style: TextStyle(
        color: context.dreamColors.muted,
        fontSize: 12.sp,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

String _formatTradeSubmissionTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final meridiem = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $meridiem';
}
