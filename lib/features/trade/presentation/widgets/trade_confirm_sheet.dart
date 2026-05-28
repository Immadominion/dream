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
    final takerFeeBps = market?.takerFeeRateBps ?? 5.0;
    final slippageBps = tradeState.orderType == OrderType.market
        ? tradeState.slippageBps
        : 0;
    final notional = tradeNotionalUsdc(
      collateralUsdc: tradeState.sizeUsdc,
      leverage: tradeState.leverage,
      takerFeeRateBps: takerFeeBps,
      slippageBps: slippageBps,
    );
    final qty = entryPrice > 0
        ? tradeBaseQuantity(
            collateralUsdc: tradeState.sizeUsdc,
            leverage: tradeState.leverage,
            markPrice: entryPrice,
            takerFeeRateBps: takerFeeBps,
            slippageBps: slippageBps,
          )
        : tradeState.quantity;
    final estFee = notional * takerFeeBps / 10000;
    final liqPrice = tradeState.estimatedLiqPrice;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
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
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 3.h,
                    ),
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
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 2.h,
                    ),
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
              Column(
                children: [
                  _ConfirmRow(
                    label: 'Size',
                    value: '${qty.toStringAsFixed(4)} $baseSymbol',
                    sub: '\$${notional.toStringAsFixed(2)} notional',
                  ),
                  SizedBox(height: 15.h),
                  _ConfirmRow(
                    label: tradeState.orderType == OrderType.market
                        ? 'Est. Entry'
                        : 'Limit Price',
                    value: entryPrice > 0 ? formatPrice(entryPrice) : '--',
                  ),
                  SizedBox(height: 15.h),
                  _ConfirmRow(
                    label: 'Collateral',
                    value: '\$${tradeState.sizeUsdc.toStringAsFixed(2)} USDC',
                    sub: 'Includes isolated margin safety buffer',
                  ),
                  SizedBox(height: 15.h),
                  _ConfirmRow(
                    label: 'Est. Fee',
                    value:
                        '~\$${estFee.toStringAsFixed(3)} (${takerFeeBps.toStringAsFixed(1)} bps)',
                    valueColor: AppColors.textSecondaryDark,
                  ),
                  if (liqPrice != null && liqPrice > 0) ...[
                    SizedBox(height: 15.h),
                    _ConfirmRow(
                      label: 'Est. Liq. Price',
                      value: formatPrice(liqPrice),
                      valueColor: AppColors.bearish,
                    ),
                  ],
                  if (tradeState.tpSlEnabled &&
                      tradeState.takeProfitPrice != null) ...[
                    SizedBox(height: 15.h),
                    _ConfirmRow(
                      label: 'Take Profit',
                      value: formatPrice(tradeState.takeProfitPrice!),
                      valueColor: AppColors.bullish,
                    ),
                  ],
                  if (tradeState.tpSlEnabled &&
                      tradeState.stopLossPrice != null) ...[
                    SizedBox(height: 15.h),
                    _ConfirmRow(
                      label: 'Stop Loss',
                      value: formatPrice(tradeState.stopLossPrice!),
                      valueColor: AppColors.bearish,
                    ),
                  ],
                ],
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.borderDark),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 13.h),
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
                          borderRadius: BorderRadius.circular(22.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 13.h),
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private helpers used only within this file
// ---------------------------------------------------------------------------

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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12.sp),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 9.h),
            child: const _DottedConnector(),
          ),
        ),
        SizedBox(width: 8.w),
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

class _DottedConnector extends StatelessWidget {
  const _DottedConnector();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: CustomPaint(
        painter: _DottedConnectorPainter(
          color: AppColors.borderDark.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

class _DottedConnectorPainter extends CustomPainter {
  final Color color;

  const _DottedConnectorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, 0),
        Offset((x + 2).clamp(0, size.width), 0),
        paint,
      );
      x += 6;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedConnectorPainter oldDelegate) =>
      oldDelegate.color != color;
}
