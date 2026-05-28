import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import 'account_history_providers.dart';
import 'account_history_shared.dart';

// ---------------------------------------------------------------------------
// Funding history tab + row
// ---------------------------------------------------------------------------

class AccountFundingHistoryTab extends ConsumerWidget {
  final String walletAddress;
  const AccountFundingHistoryTab({super.key, required this.walletAddress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = accountFundingHistoryProvider(walletAddress);
    final historyAsync = ref.watch(provider);

    Future<void> refresh() async {
      ref.invalidate(provider);
      await ref.read(provider.future);
    }

    return historyAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: AppColors.primary,
        ),
      ),
      error: (e, _) => RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceDark,
        onRefresh: refresh,
        child: buildAccountHistoryFallbackScrollView(
          child: const AccountHistoryErrorState(),
        ),
      ),
      data: (items) => RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceDark,
        onRefresh: refresh,
        child: items.isEmpty
            ? buildAccountHistoryFallbackScrollView(
                child: const AccountHistoryEmptyState(
                  title: 'No funding history',
                  description:
                      'Funding payments will appear here while you hold positions.',
                ),
              )
            : ListView.separated(
                physics: accountHistoryScrollPhysics,
                padding: EdgeInsets.fromLTRB(
                  16.w,
                  4.h,
                  16.w,
                  MediaQuery.paddingOf(context).bottom + 28.h,
                ),
                itemCount: items.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: AppColors.borderDark.withValues(alpha: 0.5),
                ),
                itemBuilder: (_, i) => _FundingHistoryRow(data: items[i]),
              ),
      ),
    );
  }
}

class _FundingHistoryRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _FundingHistoryRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final symbol = data['symbol'] as String? ?? '-';
    final amount = parseAccountHistoryDouble(data['amount']);
    final positionSize = parseAccountHistoryDouble(data['positionSize']);
    final ratePct = parseAccountHistoryDouble(data['ratePct']);
    final positionSide = data['positionSide'] as String? ?? '';
    final positive = amount >= 0;
    final color = positive ? AppColors.bullish : AppColors.bearish;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14.h),
      child: Row(
        children: [
          Icon(
            positive
                ? PhosphorIcons.arrowDown(PhosphorIconsStyle.bold)
                : PhosphorIcons.arrowUp(PhosphorIconsStyle.bold),
            color: color,
            size: 22.sp,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$symbol Funding',
                  style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  formatAccountHistoryDate(data['timestamp']),
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 12.sp,
                  ),
                ),
                if (positionSize > 0) ...[
                  SizedBox(height: 4.h),
                  Text(
                    '$positionSide ${positionSize.toStringAsFixed(4)} ${symbol.split('-').first}',
                    style: TextStyle(
                      color: AppColors.textMutedDark,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${positive ? '+' : ''}\$${amount.abs().toStringAsFixed(4)}',
                style: TextStyle(
                  color: color,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '${ratePct >= 0 ? '+' : ''}${ratePct.toStringAsFixed(4)}%',
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 11.sp,
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
// Collateral history tab + row
// ---------------------------------------------------------------------------

class AccountCollateralHistoryTab extends ConsumerWidget {
  final String walletAddress;
  const AccountCollateralHistoryTab({super.key, required this.walletAddress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = accountCollateralHistoryProvider(walletAddress);
    final historyAsync = ref.watch(provider);

    Future<void> refresh() async {
      ref.invalidate(provider);
      await ref.read(provider.future);
    }

    return historyAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: AppColors.primary,
        ),
      ),
      error: (e, _) => RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceDark,
        onRefresh: refresh,
        child: buildAccountHistoryFallbackScrollView(
          child: const AccountHistoryErrorState(),
        ),
      ),
      data: (items) => RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceDark,
        onRefresh: refresh,
        child: items.isEmpty
            ? buildAccountHistoryFallbackScrollView(
                child: const AccountHistoryEmptyState(
                  title: 'No collateral activity',
                  description:
                      'Deposits and withdrawals will appear here after you move margin.',
                  ctaLabel: 'Back to Account →',
                  targetTabIndex: 3,
                ),
              )
            : ListView.separated(
                physics: accountHistoryScrollPhysics,
                padding: EdgeInsets.fromLTRB(
                  16.w,
                  4.h,
                  16.w,
                  MediaQuery.paddingOf(context).bottom + 28.h,
                ),
                itemCount: items.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: AppColors.borderDark.withValues(alpha: 0.5),
                ),
                itemBuilder: (_, i) => _CollateralHistoryRow(data: items[i]),
              ),
      ),
    );
  }
}

class _CollateralHistoryRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CollateralHistoryRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final typeRaw =
        data['type'] as String? ??
        data['kind'] as String? ??
        data['eventType'] as String? ??
        'unknown';
    final amount = parseAccountHistoryDouble(data['amount']);
    final balanceAfter = parseAccountHistoryDouble(data['collateralAfter']);
    final isDeposit =
        typeRaw.toLowerCase().contains('deposit') ||
        (typeRaw.toLowerCase().contains('transfer') && amount >= 0);
    final color = isDeposit ? AppColors.bullish : AppColors.bearish;
    final label = isDeposit ? 'Collateral Deposit' : 'Collateral Withdrawal';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14.h),
      child: Row(
        children: [
          Icon(
            isDeposit
                ? PhosphorIcons.trayArrowDown(PhosphorIconsStyle.bold)
                : PhosphorIcons.trayArrowUp(PhosphorIconsStyle.bold),
            color: color,
            size: 22.sp,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  formatAccountHistoryDate(data['timestamp']),
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Balance ${balanceAfter.toStringAsFixed(2)} USDC',
                  style: TextStyle(
                    color: AppColors.textMutedDark,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            '${amount >= 0 ? '+' : '-'}\$${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
