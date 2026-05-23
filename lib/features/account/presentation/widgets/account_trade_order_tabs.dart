import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/models/phoenix/phoenix_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import 'account_history_providers.dart';

// ---------------------------------------------------------------------------
// Trade history tab + row
// ---------------------------------------------------------------------------

class AccountTradeHistoryTab extends ConsumerStatefulWidget {
  final String walletAddress;
  const AccountTradeHistoryTab({super.key, required this.walletAddress});

  @override
  ConsumerState<AccountTradeHistoryTab> createState() =>
      _AccountTradeHistoryTabState();
}

class _AccountTradeHistoryTabState
    extends ConsumerState<AccountTradeHistoryTab> {
  static const _pageSize = 20;
  int _displayCount = _pageSize;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(
      accountTradeHistoryProvider(widget.walletAddress),
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
      data: (trades) {
        if (trades.isEmpty) {
          return Center(
            child: Text(
              'No trades yet',
              style: TextStyle(color: AppColors.textMutedDark, fontSize: 12.sp),
            ),
          );
        }
        final visible = trades.take(_displayCount).toList();
        final hasMore = trades.length > _displayCount;
        // +1 for the "Load more" row when applicable
        final itemCount = visible.length + (hasMore ? 1 : 0);
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: itemCount,
          separatorBuilder: (_, i) =>
              Divider(height: 1, color: AppColors.borderDark),
          itemBuilder: (_, i) {
            if (i == visible.length) {
              // "Load more" button
              return TextButton(
                onPressed: () => setState(() => _displayCount += _pageSize),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                ),
                child: Text(
                  'Load more',
                  style: TextStyle(color: AppColors.primary, fontSize: 13.sp),
                ),
              );
            }
            return _TradeHistoryRow(trade: visible[i]);
          },
        );
      },
    );
  }
}

class _TradeHistoryRow extends StatelessWidget {
  final PhoenixTradeHistoryItem trade;
  const _TradeHistoryRow({required this.trade});

  @override
  Widget build(BuildContext context) {
    final sideColor = trade.isBuy ? AppColors.bullish : AppColors.bearish;
    final dt = trade.dateTime;
    final dateStr =
        '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final priceStr = _formatPrice(trade.price);
    final sizeStr = trade.size.toStringAsFixed(4);
    final baseSymbol = trade.symbol.split('-').first;

    return InkWell(
      onTap: () => _showTradeDetail(context, trade),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: Row(
          children: [
            SizedBox(
              width: 70.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    baseSymbol,
                    style: TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
            SizedBox(
              width: 50.w,
              child: Text(
                trade.isBuy ? 'Long' : 'Short',
                style: TextStyle(
                  color: sideColor,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '\$$priceStr',
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 11.sp,
                ),
              ),
            ),
            Text(
              sizeStr,
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 11.sp,
              ),
            ),
            SizedBox(width: 4.w),
            Icon(
              Icons.chevron_right,
              size: 14.r,
              color: AppColors.textMutedDark,
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 10000) return addThousandsSep(price.toStringAsFixed(0));
    if (price >= 1000) {
      final parts = price.toStringAsFixed(1).split('.');
      return '${addThousandsSep(parts[0])}.${parts[1]}';
    }
    if (price >= 100) return price.toStringAsFixed(2);
    return price.toStringAsFixed(3);
  }

  void _showTradeDetail(BuildContext context, PhoenixTradeHistoryItem trade) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (_) => _TradeDetailSheet(trade: trade),
    );
  }
}

// ---------------------------------------------------------------------------
// Order history tab + row
// ---------------------------------------------------------------------------

class AccountOrderHistoryTab extends ConsumerWidget {
  final String walletAddress;
  const AccountOrderHistoryTab({super.key, required this.walletAddress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(accountOrderHistoryProvider(walletAddress));
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
                'No order history',
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
              itemBuilder: (_, i) => _OrderHistoryRow(data: items[i]),
            ),
    );
  }
}

class _OrderHistoryRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _OrderHistoryRow({required this.data});

  static const _statusColors = {
    'filled': AppColors.bullish,
    'cancelled': AppColors.textMutedDark,
    'expired': AppColors.textMutedDark,
    'partial': AppColors.primary,
  };

  @override
  Widget build(BuildContext context) {
    final symbol = data['symbol'] as String? ?? '-';
    final side = (data['side'] as String? ?? '').toLowerCase();
    final statusRaw =
        (data['status'] as String? ?? data['orderStatus'] as String? ?? '')
            .toLowerCase();
    final amountRaw = data['quantity'] ?? data['size'] ?? data['amount'];
    final amount = amountRaw is num
        ? amountRaw.toDouble()
        : double.tryParse(amountRaw?.toString() ?? '0') ?? 0.0;
    final priceRaw = data['price'] ?? data['limitPrice'];
    final price = priceRaw is num
        ? priceRaw.toDouble()
        : double.tryParse(priceRaw?.toString() ?? '0') ?? 0.0;
    final orderTypeRaw =
        (data['orderType'] as String? ?? data['type'] as String? ?? 'market')
            .toLowerCase();
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
    final sideColor = side == 'buy' ? AppColors.bullish : AppColors.bearish;
    final statusColor = _statusColors[statusRaw] ?? AppColors.textSecondaryDark;
    final base = symbol.split('-').first;
    final isMarket = orderTypeRaw == 'market';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: sideColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(3.r),
            ),
            child: Text(
              side == 'buy' ? 'LONG' : 'SHORT',
              style: TextStyle(
                color: sideColor,
                fontSize: 9.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      symbol,
                      style: TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      isMarket ? 'MKT' : 'LMT',
                      style: TextStyle(
                        color: AppColors.textMutedDark,
                        fontSize: 9.sp,
                      ),
                    ),
                  ],
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price > 0 ? formatPrice(price) : 'Market',
                style: TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${amount.toStringAsFixed(4)} $base',
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 9.sp,
                ),
              ),
            ],
          ),
          SizedBox(width: 8.w),
          Text(
            statusRaw.isNotEmpty
                ? statusRaw[0].toUpperCase() + statusRaw.substring(1)
                : '-',
            style: TextStyle(
              color: statusColor,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trade detail bottom sheet
// ---------------------------------------------------------------------------

class _TradeDetailSheet extends StatelessWidget {
  final PhoenixTradeHistoryItem trade;
  const _TradeDetailSheet({required this.trade});

  @override
  Widget build(BuildContext context) {
    final sideColor = trade.isBuy ? AppColors.bullish : AppColors.bearish;
    final baseSymbol = trade.symbol.split('-').first;
    final notional = trade.price * trade.size;
    final dt = trade.dateTime.toLocal();

    final dateFull =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 28.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 16.h),
                decoration: BoxDecoration(
                  color: AppColors.borderDark,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Text(
                  trade.symbol,
                  style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: sideColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    trade.isBuy ? 'LONG' : 'SHORT',
                    style: TextStyle(
                      color: sideColor,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              dateFull,
              style: TextStyle(color: AppColors.textMutedDark, fontSize: 11.sp),
            ),

            SizedBox(height: 20.h),

            // Details grid
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                children: [
                  _DetailRow(
                    label: 'Fill Price',
                    value: formatPrice(trade.price),
                  ),
                  _DetailRow(
                    label: 'Size',
                    value: '${trade.size.toStringAsFixed(4)} $baseSymbol',
                  ),
                  _DetailRow(
                    label: 'Notional',
                    value: '\$${notional.toStringAsFixed(2)}',
                  ),
                  _DetailRow(
                    label: 'Fee',
                    value: trade.fee > 0
                        ? '\$${trade.fee.toStringAsFixed(4)}'
                        : '--',
                    valueColor: AppColors.bearish,
                  ),
                  _DetailRow(
                    label: 'Market',
                    value: trade.symbol,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isLast;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 13.sp,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? AppColors.textPrimaryDark,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: AppColors.borderDark),
      ],
    );
  }
}
