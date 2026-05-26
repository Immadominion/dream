import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/intelligence_models.dart';

/// A single AI bot log entry row.
class BotLogTile extends StatelessWidget {
  final BotLogEntry entry;
  const BotLogTile({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor, actionLabel) = _actionMeta(entry.action);
    final timeStr = _formatTime(entry.timestamp);

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action icon
          Container(
            width: 28.r,
            height: 28.r,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Icon(icon, color: iconColor, size: 14.r),
          ),
          SizedBox(width: 10.w),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      actionLabel,
                      style: TextStyle(
                        color: iconColor,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: AppColors.textMutedDark,
                        fontSize: 10.sp,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 3.h),
                Text(
                  entry.reason,
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 11.sp,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (entry.txSignature != null) ...[
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(
                        PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                        size: 10.r,
                        color: AppColors.success,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'Tx: ${entry.txSignature!.substring(0, 8)}…',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 10.sp,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, String) _actionMeta(BotAction action) {
    switch (action) {
      case BotAction.buy:
        return (
          PhosphorIcons.trendUp(PhosphorIconsStyle.bold),
          AppColors.bullish,
          'LONG',
        );
      case BotAction.sell:
        return (
          PhosphorIcons.trendDown(PhosphorIconsStyle.bold),
          AppColors.bearish,
          'SHORT',
        );
      case BotAction.hold:
        return (
          PhosphorIcons.pause(PhosphorIconsStyle.bold),
          AppColors.textMutedDark,
          'HOLD',
        );
    }
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}
