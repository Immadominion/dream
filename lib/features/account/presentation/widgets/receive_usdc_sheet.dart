import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/dream_colors.dart';

/// Bottom sheet that shows the user's wallet address + QR for receiving USDC.
///
/// Shows the wallet address used to receive Solana USDC before depositing it
/// into Phoenix collateral.
class ReceiveUsdcSheet extends StatelessWidget {
  final String walletAddress;
  const ReceiveUsdcSheet({super.key, required this.walletAddress});

  static Future<void> show(BuildContext context, String walletAddress) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.dreamColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => ReceiveUsdcSheet(walletAddress: walletAddress),
    );
  }

  String get _shortAddress {
    if (walletAddress.length < 12) return walletAddress;
    return '${walletAddress.substring(0, 6)}...${walletAddress.substring(walletAddress.length - 6)}';
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: walletAddress));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Wallet address copied'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16.w),
        ),
      );
    }
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(
        text: walletAddress,
        subject: 'My Solana wallet address (Dream)',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 16.h),
                decoration: BoxDecoration(
                  color: context.dreamColors.stroke,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            Text(
              'Receive USDC',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.dreamColors.onSurface,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Send Solana USDC here, then deposit it to Phoenix collateral',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.dreamColors.muted,
                fontSize: 12.sp,
              ),
            ),
            SizedBox(height: 20.h),

            // QR card
            Container(
              padding: EdgeInsets.all(20.w),
              margin: EdgeInsets.symmetric(horizontal: 40.w),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(200),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Center(
                child: QrImageView(
                  data: walletAddress,
                  version: QrVersions.auto,
                  size: 220.w,
                  backgroundColor: Colors.transparent,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.white,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16.h),

            // Address row
            InkWell(
              onTap: () => _copy(context),
              borderRadius: BorderRadius.circular(10.r),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),

                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wallet address',
                            style: TextStyle(
                              color: context.dreamColors.mutedSecondary,
                              fontSize: 11.sp,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            _shortAddress,
                            style: TextStyle(
                              color: context.dreamColors.onSurface,
                              fontSize: 13.sp,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.copy_rounded,
                      size: 18.sp,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12.h),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copy(context),
                    icon: Icon(Icons.copy_rounded, size: 16.sp),
                    label: const Text('Copy'),
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
                  child: OutlinedButton.icon(
                    onPressed: _share,
                    icon: Icon(Icons.ios_share_rounded, size: 16.sp),
                    label: const Text('Share'),
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
              ],
            ),
            SizedBox(height: 16.h),

            // Warning
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16.sp,
                  color: AppColors.bearish,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Dream trading uses Phoenix collateral. Keep a small SOL '
                    'balance here for network fees, and do not send funds over '
                    'non-Solana networks.',
                    style: TextStyle(
                      color: context.dreamColors.onSurface,
                      fontSize: 11.sp,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
