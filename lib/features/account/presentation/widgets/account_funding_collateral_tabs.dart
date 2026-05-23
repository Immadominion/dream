import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import 'account_history_providers.dart';

// ---------------------------------------------------------------------------
// Funding history tab + row
// ---------------------------------------------------------------------------

class AccountFundingHistoryTab extends ConsumerWidget {
  final String walletAddress;
  const AccountFundingHistoryTab({super.key, required this.walletAddress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(
      accountFundingHistoryProvider(walletAddress),
    );
    return historyAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: AppColors.primary,
        ),
      ),
      error: (e, _) => Center(
        child: Text(
          'Failed to load',
          style: TextStyle(color: AppColors.textMutedDark, fontSize: 12.sp),
        ),
      ),
      data: (items) => items.isEmpty
          ? Center(
              child: Text(
                'No funding history',
                style: TextStyle(
                  color: AppColors.textMutedDark,
                  fontSize: 12.sp,
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: items.take(20).length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: AppColors.borderDark),
              itemBuilder: (_, i) => _FundingHistoryRow(data: items[i]),
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
    final amountRaw = data['amount'];
    final amount = amountRaw is num
        ? amountRaw.toDouble()
        : double.tryParse(amountRaw?.toString() ?? '0') ?? 0.0;
    final tsRaw = data['timestamp'] ?? data['createdAt'] ?? data['time'];
    final ts = tsRaw != null
        ? DateTime.fromMillisecondsSinceEpoch(
            (tsRaw is int ? tsRaw : int.tryParse(tsRaw.toString()) ?? 0),
            isUtc: true,
          )
        : null;
    final dateStr = ts != null
        ? '${ts.month.toString().padLeft(2, '0')}/${ts.day.toString().padLeft(2, '0')} '
              '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}'
        : '';
    final positive = amount >= 0;
    final color = positive ? AppColors.bullish : AppColors.bearish;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  symbol,
                  style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (dateStr.isNotEmpty)
                  Text(
                    dateStr,
                    style: TextStyle(
                      color: AppColors.textMutedDark,
                      fontSize: 9.sp,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${positive ? '+' : ''}\$${amount.abs().toStringAsFixed(4)}',
            style: TextStyle(
              color: color,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
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
    final historyAsync = ref.watch(
      accountCollateralHistoryProvider(walletAddress),
    );
    return historyAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: AppColors.primary,
        ),
      ),
      error: (e, _) => Center(
        child: Text(
          'Failed to load',
          style: TextStyle(color: AppColors.textMutedDark, fontSize: 12.sp),
        ),
      ),
      data: (items) => items.isEmpty
          ? Center(
              child: Text(
                'No deposits or withdrawals',
                style: TextStyle(
                  color: AppColors.textMutedDark,
                  fontSize: 12.sp,
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: items.take(20).length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: AppColors.borderDark),
              itemBuilder: (_, i) => _CollateralHistoryRow(data: items[i]),
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
    final isDeposit = typeRaw.toLowerCase().contains('deposit');
    final amountRaw = data['amount'];
    final amount = amountRaw is num
        ? amountRaw.toDouble()
        : double.tryParse(amountRaw?.toString() ?? '0') ?? 0.0;
    final tsRaw = data['timestamp'] ?? data['createdAt'] ?? data['time'];
    final ts = tsRaw != null
        ? DateTime.fromMillisecondsSinceEpoch(
            (tsRaw is int ? tsRaw : int.tryParse(tsRaw.toString()) ?? 0),
            isUtc: true,
          )
        : null;
    final dateStr = ts != null
        ? '${ts.month.toString().padLeft(2, '0')}/${ts.day.toString().padLeft(2, '0')} '
              '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}'
        : '';
    final color = isDeposit ? AppColors.bullish : AppColors.bearish;
    final label = isDeposit ? 'Deposit' : 'Withdraw';
    final prefix = isDeposit ? '+' : '-';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          if (dateStr.isNotEmpty)
            Expanded(
              child: Text(
                dateStr,
                style: TextStyle(
                  color: AppColors.textMutedDark,
                  fontSize: 10.sp,
                ),
              ),
            )
          else
            const Spacer(),
          Text(
            '$prefix\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
