import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth/client_auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/account_provider.dart';
import '../widgets/account_activate_card.dart';
import '../widgets/account_analytics_card.dart';
import '../widgets/account_balance_card.dart';
import '../widgets/account_builder_fees.dart';
import '../widgets/account_history.dart';
import '../widgets/account_leaderboard_card.dart';
import '../widgets/account_pnl_chart.dart';
import '../widgets/account_portfolio_card.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(clientAuthProvider);
    final accountState = ref.watch(accountProvider);
    final walletAddress = authState.walletAddress;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceDark,
          onRefresh: () => ref.read(accountProvider.notifier).refresh(),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16.w,
              16.h,
              16.w,
              MediaQuery.paddingOf(context).bottom + 24.h,
            ),
            children: [
              // Wallet address card
              if (walletAddress != null)
                AccountWalletCard(address: walletAddress),
              if (walletAddress != null) SizedBox(height: 8.h),
              if (walletAddress != null)
                AccountBalanceCard(
                  walletAddress: walletAddress,
                  accountState: accountState,
                ),
              if (walletAddress != null) SizedBox(height: 12.h),

              // Error banner
              if (accountState.error != null &&
                  accountState.traderState == null) ...[
                AccountErrorBanner(
                  error: accountState.error!,
                  onRetry: () => ref.read(accountProvider.notifier).refresh(),
                ),
                SizedBox(height: 12.h),
              ],

              // Portfolio summary
              if (accountState.isLoading && accountState.traderState == null)
                const AccountLoadingCard()
              else if (accountState.traderState != null &&
                  accountState.traderState!.isRegistered)
                AccountPortfolioCard(accountState: accountState)
              else
                AccountActivateCard(walletAddress: walletAddress),

              SizedBox(height: 12.h),

              // Risk tier
              if (accountState.traderState != null) ...[
                AccountRiskCard(accountState: accountState),
                SizedBox(height: 12.h),
              ],

              // Flight builder fee card — only shown if a builder authority is configured
              if (AppConstants.phoenixBuilderAuthority.isNotEmpty) ...[
                const AccountBuilderFeesCard(),
                SizedBox(height: 12.h),
              ],

              // History (Trades | Funding | Collateral)
              if (walletAddress != null &&
                  accountState.traderState != null &&
                  accountState.traderState!.isRegistered) ...[
                AccountAnalyticsCard(walletAddress: walletAddress),
                SizedBox(height: 12.h),
                AccountLeaderboardCard(walletAddress: walletAddress),
                SizedBox(height: 12.h),
                AccountPnlChartSection(walletAddress: walletAddress),
                SizedBox(height: 12.h),
                AccountHistorySection(walletAddress: walletAddress),
                SizedBox(height: 12.h),
                const AccountReferralCard(),
                SizedBox(height: 12.h),
              ],

              // Sign out
              _AccountSignOutButton(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sign out
// ---------------------------------------------------------------------------

class _AccountSignOutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surfaceDark,
            title: Text(
              'Sign Out',
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 16.sp,
              ),
            ),
            content: Text(
              'Are you sure you want to sign out?',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 13.sp,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(color: AppColors.bearish),
                ),
              ),
            ],
          ),
        );

        if (confirm == true && context.mounted) {
          await ref.read(clientAuthProvider.notifier).signOut();
          if (context.mounted) context.go('/enhanced-login');
        }
      },
      icon: Icon(Icons.logout, color: AppColors.textSecondaryDark, size: 16.sp),
      label: Text(
        'Sign Out',
        style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 14.sp),
      ),
    );
  }
}
