import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/dream_colors.dart';

/// Success view shown in WithdrawUsdcSheet after a transaction is submitted.
class WithdrawSuccessView extends StatelessWidget {
  const WithdrawSuccessView({
    super.key,
    required this.onOpenExplorer,
    required this.onDone,
  });

  final VoidCallback onOpenExplorer;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 16.h),
        Container(
          width: 56.w,
          height: 56.w,
          decoration: BoxDecoration(
            color: AppColors.bullish.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_rounded,
            color: AppColors.bullish,
            size: 32.sp,
          ),
        ),
        SizedBox(height: 16.h),
        Text(
          'Transaction sent',
          style: TextStyle(
            color: context.dreamColors.onSurface,
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          'Your USDC transfer was submitted to the network',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.dreamColors.muted, fontSize: 12.sp),
        ),
        SizedBox(height: 20.h),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onOpenExplorer,
                icon: Icon(Icons.open_in_new_rounded, size: 14.sp),
                label: const Text('Explorer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.dreamColors.onSurface,
                  side: BorderSide(color: context.dreamColors.stroke),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
