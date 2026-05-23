import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../markets/providers/markets_provider.dart';
import '../../providers/trade_provider.dart';

// ---------------------------------------------------------------------------
// Order confirmation bottom sheet — shown before submitting
// ---------------------------------------------------------------------------

class TradeConfirmSheet extends ConsumerWidget {
  final TradeState tradeState;
  const TradeConfirmSheet({super.key, required this.tradeState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marketsState = ref.watch(marketsProvider);
    final market = marketsState.markets
        .where((m) => m.symbol == tradeState.symbol)
        .firstOrNull;
    final markPrice = marketsState.priceFor(tradeState.symbol);

    final baseSymbol = tradeState.symbol.split('-').first;
    final isLong = tradeState.side == OrderSide.buy;
    final sideColor = isLong ? AppColors.bullish : AppColors.bearish;
    final sideLabel = isLong ? 'Long' : 'Short';

    final entryPrice = tradeState.orderType == OrderType.market
        ? markPrice
        : tradeState.price;
    final notional = tradeState.sizeUsdc * tradeState.leverage;
    final qty = entryPrice > 0 ? notional / entryPrice : tradeState.quantity;
    final takerFeeBps = market?.takerFeeRateBps ?? 5.0;
    final estFee = notional * takerFeeBps / 10000;
    final liqPrice = tradeState.estimatedLiqPrice;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 36.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 18.h),
                decoration: BoxDecoration(
                  color: AppColors.borderDark,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: sideColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    '$sideLabel ${tradeState.leverage.toInt()}×',
                    style: TextStyle(
                      color: sideColor,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  tradeState.symbol,
                  style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(4.r),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Text(
                    tradeState.orderType == OrderType.market
                        ? 'Market'
                        : 'Limit',
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 11.sp,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 18.h),
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                children: [
                  _ConfirmRow(
                    label: 'Size',
                    value: '${qty.toStringAsFixed(4)} $baseSymbol',
                    sub: '\$${notional.toStringAsFixed(2)} notional',
                  ),
                  const _ConfirmDivider(),
                  _ConfirmRow(
                    label: tradeState.orderType == OrderType.market
                        ? 'Est. Entry'
                        : 'Limit Price',
                    value: entryPrice > 0 ? formatPrice(entryPrice) : '--',
                  ),
                  const _ConfirmDivider(),
                  _ConfirmRow(
                    label: 'Collateral',
                    value: '\$${tradeState.sizeUsdc.toStringAsFixed(2)} USDC',
                  ),
                  const _ConfirmDivider(),
                  _ConfirmRow(
                    label: 'Est. Fee',
                    value:
                        '~\$${estFee.toStringAsFixed(3)} (${takerFeeBps.toStringAsFixed(1)} bps)',
                    valueColor: AppColors.textSecondaryDark,
                  ),
                  if (liqPrice != null && liqPrice > 0) ...[
                    const _ConfirmDivider(),
                    _ConfirmRow(
                      label: 'Est. Liq. Price',
                      value: formatPrice(liqPrice),
                      valueColor: AppColors.bearish,
                    ),
                  ],
                  if (tradeState.tpSlEnabled &&
                      tradeState.takeProfitPrice != null) ...[
                    const _ConfirmDivider(),
                    _ConfirmRow(
                      label: 'Take Profit',
                      value: formatPrice(tradeState.takeProfitPrice!),
                      valueColor: AppColors.bullish,
                    ),
                  ],
                  if (tradeState.tpSlEnabled &&
                      tradeState.stopLossPrice != null) ...[
                    const _ConfirmDivider(),
                    _ConfirmRow(
                      label: 'Stop Loss',
                      value: formatPrice(tradeState.stopLossPrice!),
                      valueColor: AppColors.bearish,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.borderDark),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sideColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                    child: Text(
                      'Confirm $sideLabel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
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

// ---------------------------------------------------------------------------
// Private helpers used only within this file
// ---------------------------------------------------------------------------

class _ConfirmDivider extends StatelessWidget {
  const _ConfirmDivider();

  @override
  Widget build(BuildContext context) =>
      Divider(height: 16.h, color: AppColors.borderDark, thickness: 0.5);
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? valueColor;

  const _ConfirmRow({
    required this.label,
    required this.value,
    this.sub,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12.sp),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.textPrimaryDark,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (sub != null)
              Text(
                sub!,
                style: TextStyle(
                  color: AppColors.textMutedDark,
                  fontSize: 10.sp,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
