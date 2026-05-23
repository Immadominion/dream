import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/price_alerts_provider.dart';

// ---------------------------------------------------------------------------
// Direction toggle chip
// ---------------------------------------------------------------------------

class PriceAlertDirectionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const PriceAlertDirectionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withOpacity(0.15)
                : AppColors.cardDark,
            borderRadius: BorderRadius.circular(6.r),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderDark,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? AppColors.primary
                    : AppColors.textSecondaryDark,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single alert row (active / triggered)
// ---------------------------------------------------------------------------

class PriceAlertRow extends StatelessWidget {
  final PriceAlert alert;
  final VoidCallback onDelete;

  const PriceAlertRow({super.key, required this.alert, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isTriggered = alert.triggered;
    return Container(
      margin: EdgeInsets.only(bottom: 6.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: isTriggered
            ? AppColors.bullish.withOpacity(0.08)
            : AppColors.cardDark,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: isTriggered
              ? AppColors.bullish.withOpacity(0.3)
              : AppColors.borderDark,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isTriggered ? Icons.check_circle_outline : Icons.pending_outlined,
            color: isTriggered ? AppColors.bullish : AppColors.textMutedDark,
            size: 14.sp,
          ),
          SizedBox(width: 8.w),
          Text(
            '${alert.directionLabel} ${alert.formattedPrice}',
            style: TextStyle(
              color: isTriggered
                  ? AppColors.bullish
                  : AppColors.textPrimaryDark,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 6.w),
          if (isTriggered)
            Text(
              '· triggered',
              style: TextStyle(color: AppColors.bullish, fontSize: 11.sp),
            ),
          const Spacer(),
          GestureDetector(
            onTap: onDelete,
            child: Icon(
              Icons.close,
              color: AppColors.textMutedDark,
              size: 16.sp,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notification permission request banner
// ---------------------------------------------------------------------------

class PriceAlertPermissionBanner extends StatelessWidget {
  final VoidCallback onRequest;
  const PriceAlertPermissionBanner({super.key, required this.onRequest});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications_off_outlined,
            color: AppColors.primary,
            size: 16.sp,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'Enable notifications to receive price alerts.',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 11.sp,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: onRequest,
            child: Text(
              'Enable',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
