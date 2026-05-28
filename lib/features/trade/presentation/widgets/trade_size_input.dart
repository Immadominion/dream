import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/providers/auth/client_auth_provider.dart';
import '../../../../core/providers/wallet/wallet_balance_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../markets/providers/markets_provider.dart';
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
    final baseSymbol = widget.tradeState.symbol.split('-').first;

    final walletAddress = ref.watch(clientAuthProvider).walletAddress;
    final usdcAsync = walletAddress != null
        ? ref.watch(walletUsdcBalanceProvider(walletAddress))
        : const AsyncValue<double>.data(0.0);
    final walletUsdc = usdcAsync.value ?? 0.0;
    final balanceUnavailable = usdcAsync.hasError && usdcAsync.value == null;
    final phoenixAvail =
        ref.watch(positionsProvider).traderState?.availableMargin ?? 0.0;
    final tradingAvail = phoenixAvail;
    final marketsState = ref.watch(marketsProvider);
    final market = marketsState.markets
        .where((m) => m.symbol == widget.tradeState.symbol)
        .firstOrNull;
    final takerFeeBps = market?.takerFeeRateBps ?? 5.0;
    final slippageBps = widget.tradeState.orderType == OrderType.market
        ? widget.tradeState.slippageBps
        : 0;
    final notional = tradeNotionalUsdc(
      collateralUsdc: sizeUsdc,
      leverage: leverage,
      takerFeeRateBps: takerFeeBps,
      slippageBps: slippageBps,
    );
    final qty = tradeBaseQuantity(
      collateralUsdc: sizeUsdc,
      leverage: leverage,
      markPrice: markPrice,
      takerFeeRateBps: takerFeeBps,
      slippageBps: slippageBps,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Collateral',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 12.sp,
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: balanceUnavailable && walletAddress != null
                        ? () => ref.invalidate(
                            walletUsdcBalanceProvider(walletAddress),
                          )
                        : tradingAvail > 0
                        ? () {
                            final val = tradingAvail.toStringAsFixed(2);
                            _ctrl.text = val;
                            ref
                                .read(tradeProvider.notifier)
                                .setSizeUsdc(tradingAvail);
                          }
                        : null,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: usdcAsync.isLoading
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 12.w,
                                  height: 12.h,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.4,
                                    color: AppColors.textMutedDark,
                                  ),
                                ),
                                SizedBox(width: 5.w),
                                Text(
                                  'Checking',
                                  style: TextStyle(
                                    color: AppColors.textMutedDark,
                                    fontSize: 11.sp,
                                  ),
                                ),
                              ],
                            )
                          : balanceUnavailable
                          ? Text(
                              'Retry balance',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Collateral: ',
                                  style: TextStyle(
                                    color: AppColors.textMutedDark,
                                    fontSize: 11.sp,
                                  ),
                                ),
                                Text(
                                  formatUsdc(tradingAvail),
                                  maxLines: 1,
                                  overflow: TextOverflow.visible,
                                  style: TextStyle(
                                    color: AppColors.textSecondaryDark,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (tradingAvail > 0) ...[
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
          SizedBox(height: 2.h),
          Text(
            'Includes isolated margin buffer for fees and execution.',
            style: TextStyle(
              color: AppColors.textMutedDark,
              fontSize: 10.sp,
            ),
          ),
        ],
        SizedBox(height: 6.h),
        TextFormField(
          controller: _ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
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
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (v) {
            final d = double.tryParse(v) ?? 0;
            ref.read(tradeProvider.notifier).setSizeUsdc(d);
          },
          onFieldSubmitted: (_) =>
              FocusManager.instance.primaryFocus?.unfocus(),
        ),
        if (phoenixAvail <= 0 && walletUsdc > 0)
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
                Expanded(
                  child: Text(
                    'Wallet ${formatUsdc(walletUsdc)} must be deposited to Phoenix collateral first',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textMutedDark,
                      fontSize: 10.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
