import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../positions/providers/positions_provider.dart';

// ---------------------------------------------------------------------------
// Active position strip — shown when user already has a position open
// ---------------------------------------------------------------------------

class TradeActivePositionStrip extends ConsumerWidget {
  final String symbol;
  const TradeActivePositionStrip({super.key, required this.symbol});

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
              color: AppColors.textPrimaryDark,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 4.w),
          Text(
            '@ ${formatPrice(position.entryPrice)}',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 11.sp,
            ),
          ),
          const Spacer(),
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
                'Open position',
                style: TextStyle(
                  color: AppColors.textMutedDark,
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
// Success banner with Solscan link and copy button
// ---------------------------------------------------------------------------

class TradeSuccessBanner extends StatelessWidget {
  final String txSig;
  const TradeSuccessBanner({super.key, required this.txSig});

  @override
  Widget build(BuildContext context) {
    final short =
        '${txSig.substring(0, 8)}…${txSig.substring(txSig.length - 8)}';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.bullish.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: AppColors.bullish,
            size: 16.sp,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'Order submitted · $short',
              style: TextStyle(color: AppColors.bullish, fontSize: 12.sp),
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse('https://solscan.io/tx/$txSig');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: AppColors.bullish.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                'Solscan ↗',
                style: TextStyle(
                  color: AppColors.bullish,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: 6.w),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: txSig));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transaction signature copied'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Icon(Icons.copy, color: AppColors.bullish, size: 14.sp),
          ),
        ],
      ),
    );
  }
}
