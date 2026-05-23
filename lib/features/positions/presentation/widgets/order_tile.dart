import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/models/phoenix/phoenix_models.dart';
import '../../../../core/services/phoenix/phoenix_order_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/positions_provider.dart';

// ---------------------------------------------------------------------------
// Open order tile — cancel conditional orders or redirect to phoenix.trade
// ---------------------------------------------------------------------------

class OrderTile extends ConsumerStatefulWidget {
  final PhoenixOpenOrder order;
  const OrderTile({super.key, required this.order});

  @override
  ConsumerState<OrderTile> createState() => _OrderTileState();
}

class _OrderTileState extends ConsumerState<OrderTile> {
  bool _cancelling = false;

  /// Derives the execution direction for a conditional order cancel request.
  /// TP on long (sell): fires when price rises ABOVE trigger → 'above'
  /// SL on long (sell): fires when price falls BELOW trigger → 'below'
  /// TP on short (buy): fires when price falls BELOW trigger → 'below'
  /// SL on short (buy): fires when price rises ABOVE trigger → 'above'
  String _deriveExecutionDirection(String side, String orderType) {
    final lower = orderType.toLowerCase();
    final isTakeProfit =
        lower.contains('take') || lower.contains('profit') || lower == 'tp';
    final isStopLoss =
        lower.contains('stop') || lower.contains('loss') || lower == 'sl';

    if (isTakeProfit) {
      return side == 'sell' ? 'above' : 'below';
    } else if (isStopLoss) {
      return side == 'sell' ? 'below' : 'above';
    }
    // Generic conditional — default to SL semantics
    return side == 'sell' ? 'below' : 'above';
  }

  /// Opens Phoenix dApp for cancelling resting limit orders, which
  /// require on-chain instructions not exposed through the REST API.
  Future<void> _openPhoenixForLimitOrder(
    BuildContext context,
    PhoenixOpenOrder order,
  ) async {
    final symbol = order.symbol.toLowerCase().replaceAll('-perp', '');
    final uri = Uri.parse('https://app.phoenix.trade/trade/$symbol-perp');
    // Capture before async gap to satisfy use_build_context_synchronously
    final messenger = ScaffoldMessenger.of(context);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: uri.toString()));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Open phoenix.trade to cancel limit orders. URL copied.',
            style: TextStyle(fontSize: 12.sp),
          ),
          duration: const Duration(seconds: 4),
          backgroundColor: AppColors.surfaceDark,
        ),
      );
    }
  }

  Future<void> _cancelOrder() async {
    if (!widget.order.isConditional ||
        widget.order.conditionalOrderIndex == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text(
          'Cancel Order',
          style: TextStyle(color: AppColors.textPrimaryDark, fontSize: 16.sp),
        ),
        content: Text(
          'Cancel this conditional order?',
          style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Keep',
              style: TextStyle(color: AppColors.textSecondaryDark),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Cancel Order',
              style: TextStyle(color: AppColors.bearish),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final walletAddress = ref.read(positionsProvider).traderState?.authority;
      if (walletAddress == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No wallet connected')));
        return;
      }

      final direction =
          widget.order.executionDirection ??
          _deriveExecutionDirection(widget.order.side, widget.order.orderType);

      final result = await ref
          .read(phoenixOrderServiceProvider)
          .cancelConditionalOrder(
            authority: walletAddress,
            symbol: widget.order.symbol,
            conditionalOrderIndex: widget.order.conditionalOrderIndex!,
            executionDirection: direction,
          );

      if (!mounted) return;

      if (result.success) {
        await Future.delayed(const Duration(seconds: 2));
        await ref.read(positionsProvider.notifier).refresh();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cancel failed: ${result.error}')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isBuy = order.side == 'buy';
    final sideColor = isBuy ? AppColors.bullish : AppColors.bearish;
    final fillPct = order.size > 0
        ? (order.filledSize / order.size * 100).toStringAsFixed(0)
        : '0';

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.symbol,
                style: TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                '${order.side.toUpperCase()} ${order.orderType}',
                style: TextStyle(
                  color: sideColor,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${order.price.toStringAsFixed(2)}',
                style: TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                'Filled $fillPct%',
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
          if (order.isConditional && order.conditionalOrderIndex != null) ...[
            SizedBox(width: 10.w),
            SizedBox(
              width: 28.w,
              height: 28.w,
              child: _cancelling
                  ? Padding(
                      padding: EdgeInsets.all(4.w),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.bearish,
                      ),
                    )
                  : IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.close,
                        size: 16.sp,
                        color: AppColors.bearish,
                      ),
                      onPressed: _cancelOrder,
                      tooltip: 'Cancel order',
                    ),
            ),
          ] else if (!order.isConditional) ...[
            SizedBox(width: 10.w),
            GestureDetector(
              onTap: () => _openPhoenixForLimitOrder(context, order),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.borderDark,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
