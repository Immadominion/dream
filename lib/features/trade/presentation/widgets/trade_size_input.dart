import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/providers/auth/client_auth_provider.dart';
import '../../../../core/providers/wallet/wallet_balance_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../positions/providers/positions_provider.dart';
import '../../providers/trade_provider.dart';

// ---------------------------------------------------------------------------
// USDC collateral size input — balance badge + inline deposit notice
// ---------------------------------------------------------------------------

class TradeSizeInput extends ConsumerStatefulWidget {
  final TradeState tradeState;
  const TradeSizeInput({super.key, required this.tradeState});

  @override
  ConsumerState<TradeSizeInput> createState() => TradeSizeInputState();
}

class TradeSizeInputState extends ConsumerState<TradeSizeInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    final v = widget.tradeState.sizeUsdc;
    _ctrl = TextEditingController(text: v > 0 ? v.toStringAsFixed(2) : '');
  }

  @override
  void didUpdateWidget(TradeSizeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tradeState.sizeUsdc > 0 && widget.tradeState.sizeUsdc == 0) {
      _ctrl.clear();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markPrice = widget.tradeState.markPrice;
    final sizeUsdc = widget.tradeState.sizeUsdc;
    final leverage = widget.tradeState.leverage;
    final notional = sizeUsdc * leverage;
    final qty = markPrice > 0 ? notional / markPrice : 0.0;
    final baseSymbol = widget.tradeState.symbol.split('-').first;

    final walletAddress = ref.watch(clientAuthProvider).walletAddress;
    final usdcAsync = walletAddress != null
        ? ref.watch(walletUsdcBalanceProvider(walletAddress))
        : const AsyncValue<double>.data(0.0);
    final walletUsdc = usdcAsync.value ?? 0.0;
    final phoenixAvail =
        ref.watch(positionsProvider).traderState?.availableMargin ?? 0.0;
    final totalAvail = walletUsdc + phoenixAvail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Collateral',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 12.sp,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: totalAvail > 0
                  ? () {
                      final val = totalAvail.toStringAsFixed(2);
                      _ctrl.text = val;
                      ref.read(tradeProvider.notifier).setSizeUsdc(totalAvail);
                    }
                  : null,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(4.r),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: usdcAsync.isLoading
                    ? SizedBox(
                        width: 14.w,
                        height: 14.h,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppColors.textMutedDark,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Avail: ',
                            style: TextStyle(
                              color: AppColors.textMutedDark,
                              fontSize: 11.sp,
                            ),
                          ),
                          Text(
                            '\$${totalAvail.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (totalAvail > 0) ...[
                            SizedBox(width: 6.w),
                            Text(
                              'Max',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        ),
        if (notional > 0) ...[
          SizedBox(height: 2.h),
          Text(
            'Notional \$${notional.toStringAsFixed(2)}  ·  '
            '${qty.toStringAsFixed(4)} $baseSymbol',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 11.sp,
            ),
          ),
        ],
        SizedBox(height: 6.h),
        TextFormField(
          controller: _ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          style: TextStyle(
            color: AppColors.textPrimaryDark,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: '0.00',
            hintStyle: TextStyle(
              color: AppColors.textMutedDark,
              fontSize: 16.sp,
            ),
            suffixText: 'USDC',
            suffixStyle: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 13.sp,
            ),
            filled: true,
            fillColor: AppColors.cardDark,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.w,
              vertical: 14.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppColors.borderDark),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppColors.borderDark),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),
          onChanged: (v) {
            final d = double.tryParse(v) ?? 0;
            ref.read(tradeProvider.notifier).setSizeUsdc(d);
          },
        ),
        if (sizeUsdc > 0 && phoenixAvail < sizeUsdc)
          Padding(
            padding: EdgeInsets.only(top: 6.h),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 12.sp,
                  color: AppColors.textMutedDark,
                ),
                SizedBox(width: 4.w),
                Text(
                  'USDC will be deposited from your wallet',
                  style: TextStyle(
                    color: AppColors.textMutedDark,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
