import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/dream_colors.dart';

/// Full-screen error state used across all feature pages.
///
/// Converts raw exception strings (DioException, SocketException, etc.)
/// into user-friendly messages and shows the bag Lottie animation.
class AppErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const AppErrorView({super.key, required this.error, required this.onRetry});

  /// Converts a raw exception string to a concise, user-readable message.
  static String friendly(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('connection timeout') ||
        s.contains('connecttimeout') ||
        s.contains('timed out')) {
      return 'Connection timed out.\nCheck your internet and try again.';
    }
    if (s.contains('receive timeout')) {
      return 'Server took too long to respond.\nTry again in a moment.';
    }
    if (s.contains('connection error') ||
        s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('network is unreachable')) {
      return 'No internet connection.\nCheck your Wi-Fi or mobile data.';
    }
    if (s.contains('401') || s.contains('unauthorized')) {
      return 'Session expired.\nSign in again to continue.';
    }
    if (s.contains('403') || s.contains('forbidden')) {
      return 'Access denied.\nYou may need to reconnect your wallet.';
    }
    if (s.contains('404') || s.contains('not found')) {
      return 'Data not found.\nIt may have moved or been removed.';
    }
    if (s.contains('500') || s.contains('502') || s.contains('503')) {
      return 'Phoenix servers are having trouble.\nTry again in a moment.';
    }
    return 'Something went wrong.\nPull down or tap Retry.';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/lottie/error.json',
              width: 120.r,
              height: 120.r,
              repeat: true,
            ),
            SizedBox(height: 16.h),
            Text(
              friendly(error),
              style: TextStyle(
                color: context.dreamColors.muted,
                fontSize: 14.sp,
                height: 1.55,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20.h),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  'Retry',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
