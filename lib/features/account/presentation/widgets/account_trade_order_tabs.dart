import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/models/phoenix/phoenix_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import 'account_history_providers.dart';
import 'account_history_shared.dart';
import '../../../../core/theme/dream_colors.dart';

class AccountTradeHistoryTab extends ConsumerWidget {
  final String walletAddress;

  const AccountTradeHistoryTab({super.key, required this.walletAddress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = accountTradeHistoryProvider(walletAddress);
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
        backgroundColor: context.dreamColors.surface,
        onRefresh: refresh,
        child: buildAccountHistoryFallbackScrollView(
          child: const AccountHistoryErrorState(),
        ),
      ),
      data: (trades) => RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: context.dreamColors.surface,
        onRefresh: refresh,
        child: trades.isEmpty
            ? buildAccountHistoryFallbackScrollView(
                child: const AccountHistoryEmptyState(
                  title: 'No trades yet',
                  description:
                      'Your fills will appear here once you open a trade.',
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
                itemCount: trades.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: context.dreamColors.stroke.withValues(alpha: 0.5),
                ),
                itemBuilder: (_, i) => _TradeHistoryRow(trade: trades[i]),
              ),
      ),
    );
  }
}

class AccountOrderHistoryTab extends ConsumerWidget {
  final String walletAddress;

  const AccountOrderHistoryTab({super.key, required this.walletAddress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = accountOrderHistoryProvider(walletAddress);
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
        backgroundColor: context.dreamColors.surface,
        onRefresh: refresh,
        child: buildAccountHistoryFallbackScrollView(
          child: const AccountHistoryErrorState(),
        ),
      ),
      data: (items) => RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: context.dreamColors.surface,
        onRefresh: refresh,
        child: items.isEmpty
            ? buildAccountHistoryFallbackScrollView(
                child: const AccountHistoryEmptyState(
                  title: 'No order history',
                  description:
                      'Your submitted orders will appear here once you trade.',
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
                  color: context.dreamColors.stroke.withValues(alpha: 0.5),
                ),
                itemBuilder: (_, i) => _OrderHistoryRow(data: items[i]),
              ),
      ),
    );
  }
}

class _TradeHistoryRow extends StatelessWidget {
  final PhoenixTradeHistoryItem trade;

  const _TradeHistoryRow({required this.trade});

  @override
  Widget build(BuildContext context) {
    final sideColor = _tradeEventColor(trade);
    final baseSymbol = trade.symbol.split('-').first;
    final title =
        '${trade.lifecycleSideLabel} $baseSymbol ${trade.lifecycleLabel}';
    final subtitle = trade.isFlipFill
        ? '${trade.instructionLabel} · now ${trade.exposureSideAfter}'
        : trade.instructionLabel;
    final hasRealizedPnl = trade.realizedPnl.abs() > 0.0000001;
    final secondaryValue = hasRealizedPnl
        ? 'PnL ${trade.realizedPnl >= 0 ? '+' : ''}\$${trade.realizedPnl.toStringAsFixed(2)}'
        : '@ ${_formatHistoryPrice(trade.price)}';
    final secondaryColor = hasRealizedPnl
        ? (trade.realizedPnl >= 0 ? AppColors.bullish : AppColors.bearish)
        : context.dreamColors.muted;

    return InkWell(
      onTap: () => _showTradeDetail(context, trade),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        child: Row(
          children: [
            Icon(
              trade.isBuy
                  ? PhosphorIcons.arrowUpRight(PhosphorIconsStyle.bold)
                  : PhosphorIcons.arrowDownRight(PhosphorIconsStyle.bold),
              color: sideColor,
              size: 22.sp,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.dreamColors.onSurface,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '$subtitle · ${formatAccountHistoryDate(trade.dateTime)}',
                    style: TextStyle(
                      color: context.dreamColors.muted,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${trade.size.toStringAsFixed(4)} $baseSymbol',
                  style: TextStyle(
                    color: context.dreamColors.onSurface,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  secondaryValue,
                  style: TextStyle(color: secondaryColor, fontSize: 12.sp),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTradeDetail(BuildContext context, PhoenixTradeHistoryItem trade) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.dreamColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (_) => _TradeDetailSheet(trade: trade),
    );
  }
}

class _OrderHistoryRow extends StatelessWidget {
  final Map<String, dynamic> data;

  const _OrderHistoryRow({required this.data});

  static Color _statusColor(String status, BuildContext context) {
    switch (status) {
      case 'filled':
        return AppColors.bullish;
      case 'partial':
      case 'open':
        return AppColors.primary;
      default: // cancelled, expired, etc.
        return context.dreamColors.mutedSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final symbol = data['symbol'] as String? ?? '-';
    final side = (data['side'] as String? ?? '').toLowerCase();
    final isBuy =
        side.contains('buy') || side.contains('bid') || side.contains('long');
    final statusRaw =
        (data['status'] as String? ?? data['orderStatus'] as String? ?? '')
            .toLowerCase();
    final amount = parseAccountHistoryDouble(
      data['quantity'] ?? data['size'] ?? data['amount'] ?? data['baseAmount'],
    );
    final price = parseAccountHistoryDouble(
      data['price'] ?? data['limitPrice'] ?? data['triggerPrice'],
    );
    final orderTypeRaw =
        (data['orderType'] as String? ?? data['type'] as String? ?? 'market')
            .toLowerCase();
    final sideColor = isBuy ? AppColors.bullish : AppColors.bearish;
    final statusColor = _statusColor(statusRaw, context);
    final base = symbol.split('-').first;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14.h),
      child: Row(
        children: [
          Icon(
            isBuy
                ? PhosphorIcons.arrowUpRight(PhosphorIconsStyle.bold)
                : PhosphorIcons.arrowDownRight(PhosphorIconsStyle.bold),
            color: sideColor,
            size: 22.sp,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isBuy ? 'Long' : 'Short'} $base',
                  style: TextStyle(
                    color: context.dreamColors.onSurface,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${orderTypeRaw.toUpperCase()} · ${formatAccountHistoryDate(data['timestamp'] ?? data['createdAt'] ?? data['time'])}',
                  style: TextStyle(
                    color: context.dreamColors.muted,
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  amount > 0 ? '${amount.toStringAsFixed(4)} $base' : symbol,
                  style: TextStyle(
                    color: context.dreamColors.mutedSecondary,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price > 0 ? formatPrice(price) : 'Market',
                style: TextStyle(
                  color: context.dreamColors.onSurface,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999.r),
                ),
                child: Text(
                  statusRaw.isNotEmpty
                      ? statusRaw[0].toUpperCase() + statusRaw.substring(1)
                      : 'Pending',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatHistoryPrice(double price) {
  if (price >= 10000) return addThousandsSep(price.toStringAsFixed(0));
  if (price >= 1000) {
    final parts = price.toStringAsFixed(1).split('.');
    return '${addThousandsSep(parts[0])}.${parts[1]}';
  }
  if (price >= 100) return price.toStringAsFixed(2);
  return price.toStringAsFixed(4);
}

Color _tradeEventColor(PhoenixTradeHistoryItem trade) {
  if (trade.isClosingFill || trade.isReduceFill) {
    if (trade.realizedPnl > 0) return AppColors.bullish;
    if (trade.realizedPnl < 0) return AppColors.bearish;
  }

  final usesLongTheme =
      (trade.isClosingFill || trade.isReduceFill || trade.isFlipFill)
      ? trade.exposureSideBefore == 'long'
      : trade.exposureSideAfter == 'long';
  return usesLongTheme ? AppColors.bullish : AppColors.bearish;
}

// ---------------------------------------------------------------------------
// Trade detail bottom sheet
// ---------------------------------------------------------------------------

class _TradeDetailSheet extends StatelessWidget {
  final PhoenixTradeHistoryItem trade;
  const _TradeDetailSheet({required this.trade});

  @override
  Widget build(BuildContext context) {
    final sideColor = _tradeEventColor(trade);
    final baseSymbol = trade.symbol.split('-').first;
    final notional = trade.price * trade.size;
    final dt = trade.dateTime.toLocal();
    final hasRealizedPnl = trade.realizedPnl.abs() > 0.0000001;

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
                  color: context.dreamColors.stroke,
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
                    color: context.dreamColors.onSurface,
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
                    trade.lifecycleLabel.toUpperCase(),
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
              style: TextStyle(
                color: context.dreamColors.mutedSecondary,
                fontSize: 11.sp,
              ),
            ),

            SizedBox(height: 20.h),

            // Details grid
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: context.dreamColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: context.dreamColors.stroke),
              ),
              child: Column(
                children: [
                  _DetailRow(
                    label: 'Event',
                    value:
                        '${trade.lifecycleSideLabel} ${trade.lifecycleLabel}',
                  ),
                  _DetailRow(
                    label: 'Instruction',
                    value: trade.instructionLabel,
                  ),
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
                    label: 'Position Before',
                    value:
                        '${trade.baseLotsBefore.toStringAsFixed(4)} $baseSymbol',
                  ),
                  _DetailRow(
                    label: 'Position After',
                    value:
                        '${trade.baseLotsAfter.toStringAsFixed(4)} $baseSymbol',
                  ),
                  _DetailRow(
                    label: 'Realized PnL',
                    value: hasRealizedPnl
                        ? '${trade.realizedPnl >= 0 ? '+' : ''}\$${trade.realizedPnl.toStringAsFixed(5)}'
                        : '--',
                    valueColor: hasRealizedPnl
                        ? (trade.realizedPnl >= 0
                              ? AppColors.bullish
                              : AppColors.bearish)
                        : null,
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
                  color: context.dreamColors.muted,
                  fontSize: 13.sp,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? context.dreamColors.onSurface,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: context.dreamColors.stroke),
      ],
    );
  }
}
