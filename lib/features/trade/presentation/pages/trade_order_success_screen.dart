import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rive/rive.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/phoenix/phoenix_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../providers/trade_state.dart';
import '../widgets/trade_receipt_sheet.dart';
import '../../../../core/theme/dream_colors.dart';

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

  String get _txLabel {
    if (trade.txSignature.isEmpty) return 'Pending';
    return '${trade.txSignature.substring(0, 6)}...${trade.txSignature.substring(trade.txSignature.length - 6)}';
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
    final c = context.dreamColors;
    final entryPrice = position?.entryPrice ?? trade.entryPrice;
    final liquidationPrice = position?.liquidationPrice ?? trade.estimatedLiqPrice;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded, color: c.onSurface, size: 22.sp),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Animation + heading ─────────────────────────────────────
              SizedBox(height: 4.h),
              Center(
                child: SizedBox(
                  width: 96.w,
                  height: 96.w,
                  child: RiveWidgetBuilder(
                    fileLoader: FileLoader.fromAsset(
                      AppAssets.successAnimation,
                      riveFactory: Factory.rive,
                    ),
                    stateMachineSelector: const StateMachineNamed(
                      'State Machine 1',
                    ),
                    builder: (context, riveState) {
                      if (riveState is RiveLoaded) {
                        return RiveWidget(
                          controller: riveState.controller,
                          fit: Fit.contain,
                        );
                      }
                      if (riveState is RiveFailed) {
                        return Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: 68.sp,
                        );
                      }
                      return Center(
                        child: SizedBox(
                          width: 22.w,
                          height: 22.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.success,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Order placed',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.onSurface,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                '$_sideLabel $_baseSymbol $_leverageLabel',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _sideColor,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 16.h),

              // ── Receipt card ─────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: c.surfaceVariant,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: c.stroke, width: 0.5),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                child: Column(
                  children: [
                    _Row(label: 'Size', value: '${trade.quantity.toStringAsFixed(4)} $_baseSymbol', c: c),
                    _Divider(c: c),
                    _Row(label: 'Collateral', value: formatUsdc(trade.collateralUsdc), c: c),
                    _Divider(c: c),
                    _Row(
                      label: trade.orderType == OrderType.market ? 'Entry price' : 'Limit price',
                      value: formatPrice(entryPrice),
                      c: c,
                    ),
                    _Divider(c: c),
                    _Row(label: 'Notional', value: formatUsdc(trade.notionalUsdc), c: c),
                    if (liquidationPrice != null && liquidationPrice > 0) ...[
                      _Divider(c: c),
                      _Row(label: 'Liq. price', value: formatPrice(liquidationPrice), c: c),
                    ],
                    _Divider(c: c),
                    _Row(label: 'Tx', value: _txLabel, c: c, valueColor: c.muted),
                  ],
                ),
              ),

              const Spacer(),

              // ── CTAs ─────────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48.h,
                      child: ElevatedButton(
                        onPressed: () => _openSharePreview(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                        child: Text(
                          'Share setup',
                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  if (trade.txSignature.isNotEmpty) ...[
                    SizedBox(width: 10.w),
                    Expanded(
                      child: SizedBox(
                        height: 48.h,
                        child: OutlinedButton(
                          onPressed: _openSolscan,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.onSurface,
                            side: BorderSide(color: c.stroke),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                          ),
                          child: Text(
                            'View live',
                            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final DreamColors c;
  final Color? valueColor;

  const _Row({required this.label, required this.value, required this.c, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 9.h),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(color: c.muted, fontSize: 12.sp, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? c.onSurface,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final DreamColors c;
  const _Divider({required this.c});

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 0.5, color: c.stroke);
  }
}