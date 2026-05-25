import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/wallet/wallet_balance_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../providers/account_provider.dart';
import 'receive_usdc_sheet.dart';
import 'withdraw_usdc_sheet.dart';

// ---------------------------------------------------------------------------
// Wallet balance card — wallet USDC + Phoenix deposited + collateral actions
// ---------------------------------------------------------------------------

class AccountBalanceCard extends ConsumerWidget {
  final String walletAddress;
  final AccountState accountState;
  const AccountBalanceCard({
    super.key,
    required this.walletAddress,
    required this.accountState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usdcAsync = ref.watch(walletUsdcBalanceProvider(walletAddress));
    final walletUsdc = usdcAsync.value ?? 0.0;
    final phoenixDeposited = accountState.collateral;
    final available = accountState.availableMargin;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),

      child: Column(
        children: [
          // Balance stats row
          Row(
            children: [
              _BalanceStat(
                label: 'Wallet USDC',
                value: usdcAsync.isLoading ? '...' : formatUsdc(walletUsdc),
                icon: PhosphorIcons.wallet(),
              ),
              _VerticalDivider(),
              _BalanceStat(
                label: 'Deposited',
                value: formatUsdc(phoenixDeposited),
                icon: PhosphorIcons.piggyBank(),
              ),
              _VerticalDivider(),
              _BalanceStat(
                label: 'Available',
                value: formatUsdc(available),
                icon: PhosphorIcons.coin(),
                valueColor: AppColors.primary,
              ),
            ],
          ),

          SizedBox(height: 12.h),

          // Wallet USDC — Receive / Send buttons
          Row(
            children: [
              Expanded(
                child: _CollateralButton(
                  label: 'Receive',
                  icon: Icons.qr_code,
                  color: AppColors.bullish,
                  onTap: () => ReceiveUsdcSheet.show(context, walletAddress),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _CollateralButton(
                  label: 'Send',
                  icon: Icons.send_outlined,
                  color: AppColors.textSecondaryDark,
                  onTap: () => WithdrawUsdcSheet.show(
                    context,
                    walletAddress: walletAddress,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 10.h),

          // Phoenix cross-margin collateral management deep link
          GestureDetector(
            onTap: () => launchUrl(
              Uri.parse('https://app.phoenix.trade'),
              mode: LaunchMode.externalApplication,
            ),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.swap_horiz,
                    size: 13.sp,
                    color: AppColors.primary.withOpacity(0.8),
                  ),
                  SizedBox(width: 5.w),
                  Text(
                    'Deposit / Withdraw Phoenix Collateral',
                    style: TextStyle(
                      color: AppColors.primary.withOpacity(0.9),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(
                    Icons.open_in_new,
                    size: 11.sp,
                    color: AppColors.primary.withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wallet address card
// ---------------------------------------------------------------------------

class AccountWalletCard extends StatelessWidget {
  final String address;
  const AccountWalletCard({super.key, required this.address});

  @override
  Widget build(BuildContext context) {
    final short =
        '${address.substring(0, 8)}…${address.substring(address.length - 8)}';
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: address));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address copied to clipboard')),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Row(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              color: AppColors.primary,
              size: 18.sp,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                short,
                style: TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 13.sp,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            Icon(Icons.copy, color: AppColors.textSecondaryDark, size: 14.sp),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error banner
// ---------------------------------------------------------------------------

class AccountErrorBanner extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const AccountErrorBanner({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.bearish.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.bearish.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.bearish, size: 16.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              error.length > 60 ? '${error.substring(0, 60)}…' : error,
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 12.sp,
              ),
            ),
          ),
          GestureDetector(
            onTap: onRetry,
            child: Text(
              'Retry',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

class _BalanceStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  const _BalanceStat({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          PhosphorIcon(icon, size: 32.sp, color: AppColors.textMutedDark),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimaryDark,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(color: AppColors.textMutedDark, fontSize: 10.sp),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 0.5, height: 36.h, color: AppColors.borderDark);
  }
}

class _CollateralButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CollateralButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36.h,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14.sp),
            SizedBox(width: 4.w),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
