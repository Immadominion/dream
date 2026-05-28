import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/phoenix/phoenix_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../providers/trade_state.dart';
import '../widgets/trade_receipt_sheet.dart';

class TradeOrderSuccessScreen extends StatelessWidget {
  final TradeSubmittedTrade trade;
  final PhoenixPosition? position;

  const TradeOrderSuccessScreen({
    super.key,
    required this.trade,
    this.position,
  });

  bool get _isLong => trade.side == OrderSide.buy;

  String get _baseSymbol => trade.symbol.split('-').first;

  String get _sideLabel => _isLong ? 'Long' : 'Short';

  Color get _sideColor => _isLong ? AppColors.bullish : AppColors.bearish;

  String get _leverageLabel =>
      trade.leverage.truncateToDouble() == trade.leverage
      ? '${trade.leverage.toStringAsFixed(0)}x'
      : '${trade.leverage.toStringAsFixed(1)}x';

  String get _orderSubtitle => trade.orderType == OrderType.market
      ? 'Market order submitted to Phoenix.'
      : 'Limit order submitted to Phoenix.';

  String get _txLabel {
    if (trade.txSignature.isEmpty) return 'Pending confirmation';
    return '${trade.txSignature.substring(0, 8)}...${trade.txSignature.substring(trade.txSignature.length - 8)}';
  }

  Future<void> _openSolscan() async {
    if (trade.txSignature.isEmpty) return;

    final uri = Uri.parse('https://solscan.io/tx/${trade.txSignature}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openSharePreview(BuildContext context) {
    TradeReceiptSheet.show(context, trade: trade, position: position);
  }

  @override
  Widget build(BuildContext context) {
    final entryPrice = position?.entryPrice ?? trade.entryPrice;
    final liquidationPrice =
        position?.liquidationPrice ?? trade.estimatedLiqPrice;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.close_rounded,
            color: AppColors.textPrimaryDark,
            size: 22.sp,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: 12.h),
                      SizedBox(
                        width: 176.w,
                        height: 176.w,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 132.w,
                              height: 132.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.success.withValues(alpha: 0.28),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            Lottie.asset(
                              AppAssets.successAnimation,
                              repeat: false,
                              width: 176.w,
                              height: 176.w,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Order placed',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimaryDark,
                          fontSize: 30.sp,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        '$_sideLabel $_baseSymbol $_leverageLabel',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _sideColor,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        _orderSubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 13.sp,
                          height: 1.45,
                        ),
                      ),
                      SizedBox(height: 28.h),
                      _SuccessMetricRow(
                        label: 'Size',
                        value:
                            '${trade.quantity.toStringAsFixed(4)} $_baseSymbol',
                      ),
                      _SuccessMetricRow(
                        label: 'Collateral',
                        value: formatUsdc(trade.collateralUsdc),
                      ),
                      _SuccessMetricRow(
                        label: trade.orderType == OrderType.market
                            ? 'Est. Entry'
                            : 'Limit Price',
                        value: formatPrice(entryPrice),
                      ),
                      _SuccessMetricRow(
                        label: 'Notional',
                        value: formatUsdc(trade.notionalUsdc),
                      ),
                      if (liquidationPrice != null && liquidationPrice > 0)
                        _SuccessMetricRow(
                          label: 'Est. Liq. Price',
                          value: formatPrice(liquidationPrice),
                        ),
                      _SuccessMetricRow(
                        label: 'Transaction',
                        value: _txLabel,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: () => _openSharePreview(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                  ),
                  child: Text(
                    'Share Setup',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimaryDark,
                    side: BorderSide(color: AppColors.borderDark),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (trade.txSignature.isNotEmpty) ...[
                SizedBox(height: 6.h),
                TextButton(
                  onPressed: _openSolscan,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondaryDark,
                  ),
                  child: Text(
                    'View on Solscan',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessMetricRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _SuccessMetricRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14.h),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textMutedDark,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (!isLast) ...[
            SizedBox(height: 14.h),
            Divider(height: 1, thickness: 1, color: AppColors.borderDark),
          ],
        ],
      ),
    );
  }
}
