import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/providers/auth/client_auth_provider.dart';
import '../../../../core/providers/phoenix/phoenix_auth_provider.dart';
import '../../../markets/providers/markets_provider.dart';
import '../../../positions/providers/positions_provider.dart';
import '../../providers/trade_provider.dart';
import '../../../../core/providers/wallet/wallet_balance_provider.dart';
import 'trade_confirm_sheet.dart';

// ---------------------------------------------------------------------------
// Order summary card — shown below the form
// ---------------------------------------------------------------------------

class TradeOrderSummary extends ConsumerWidget {
  final TradeState tradeState;
  const TradeOrderSummary({super.key, required this.tradeState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marketsState = ref.watch(marketsProvider);
    final market = marketsState.markets
        .where((m) => m.symbol == tradeState.symbol)
        .firstOrNull;
    final price = marketsState.priceFor(tradeState.symbol);
    final baseSymbol = tradeState.symbol.split('-').first;
    final notional = tradeState.sizeUsdc * tradeState.leverage;
    final qty = price > 0 ? notional / price : tradeState.quantity;
    final takerFeeBps = market?.takerFeeRateBps ?? 5.0;
    final estFee = notional * takerFeeBps / 10000;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        children: [
          _SummaryRow(
            label: 'Order type',
            value: tradeState.orderType == OrderType.market
                ? 'Market'
                : 'Limit',
          ),
          SizedBox(height: 6.h),
          _SummaryRow(
            label: 'Side',
            value: tradeState.side == OrderSide.buy ? 'Long' : 'Short',
            valueColor: tradeState.side == OrderSide.buy
                ? AppColors.bullish
                : AppColors.bearish,
          ),
          SizedBox(height: 6.h),
          _SummaryRow(
            label: 'Leverage',
            value: '${tradeState.leverage.toInt()}×',
          ),
          SizedBox(height: 6.h),
          _SummaryRow(
            label: 'Notional',
            value: notional > 0 ? '\$${notional.toStringAsFixed(2)}' : '--',
          ),
          SizedBox(height: 6.h),
          _SummaryRow(
            label: 'Size',
            value: qty > 0 ? '${qty.toStringAsFixed(4)} $baseSymbol' : '--',
          ),
          SizedBox(height: 6.h),
          _SummaryRow(
            label: 'Est. Fee',
            value: notional > 0
                ? '~\$${estFee.toStringAsFixed(3)} (${takerFeeBps.toStringAsFixed(1)} bps)'
                : '--',
            valueColor: AppColors.textSecondaryDark,
          ),
          if (tradeState.estimatedLiqPrice != null &&
              tradeState.estimatedLiqPrice! > 0) ...[
            SizedBox(height: 6.h),
            _SummaryRow(
              label: 'Est. Liq. Price',
              value: formatPrice(tradeState.estimatedLiqPrice!),
              valueColor: AppColors.bearish,
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12.sp),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimaryDark,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Submit button — validates balance, shows confirm sheet, submits order
// ---------------------------------------------------------------------------

class TradeSubmitButton extends ConsumerWidget {
  final TradeState tradeState;
  final bool isAuthed;
  const TradeSubmitButton({
    super.key,
    required this.tradeState,
    required this.isAuthed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLong = tradeState.side == OrderSide.buy;
    final buttonColor = isLong ? AppColors.bullish : AppColors.bearish;
    final baseSymbol = tradeState.symbol.split('-').first;
    final leverage = tradeState.leverage.toInt();
    final label = isLong
        ? 'Long $baseSymbol ${leverage}x'
        : 'Short $baseSymbol ${leverage}x';

    final walletAddress = ref.watch(clientAuthProvider).walletAddress;
    final phoenixAuth = ref.watch(phoenixAuthProvider);

    // Determine button label and interactability based on auth state
    final bool hasWallet = walletAddress != null;
    final bool phoenixLoading =
        phoenixAuth.status == PhoenixAuthStatus.loading ||
        phoenixAuth.status == PhoenixAuthStatus.initial;
    final bool phoenixReady = phoenixAuth.isAuthenticated;

    final String buttonLabel;
    if (!hasWallet) {
      buttonLabel = 'Connect Wallet to Trade';
    } else if (phoenixLoading) {
      buttonLabel = 'Authenticating…';
    } else if (!phoenixReady) {
      buttonLabel = 'Reconnect Wallet';
    } else {
      buttonLabel = label;
    }

    final usdcAsync = walletAddress != null
        ? ref.watch(walletUsdcBalanceProvider(walletAddress))
        : const AsyncValue<double>.data(0.0);
    final walletUsdc = usdcAsync.value ?? 0.0;
    final phoenixAvail =
        ref.watch(positionsProvider).traderState?.availableMargin ?? 0.0;
    final totalAvail = walletUsdc + phoenixAvail;

    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: ElevatedButton(
        onPressed:
            (!tradeState.canSubmit ||
                !phoenixReady ||
                !hasWallet ||
                phoenixLoading)
            ? null
            : () async {
                if (tradeState.sizeUsdc > totalAvail) {
                  ref
                      .read(tradeProvider.notifier)
                      .setSubmitError(
                        'Insufficient USDC. Available: \$${totalAvail.toStringAsFixed(2)}',
                      );
                  return;
                }
                ref.read(tradeProvider.notifier).clearResult();

                final confirmed = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AppColors.surfaceDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16.r),
                    ),
                  ),
                  builder: (_) => TradeConfirmSheet(tradeState: tradeState),
                );

                if (confirmed != true || !context.mounted) return;

                final success = await ref
                    .read(tradeProvider.notifier)
                    .submitOrder();
                if (success && context.mounted) {
                  HapticFeedback.mediumImpact();
                  ref.read(tradeProvider.notifier).setSizeUsdc(0);
                  ref.read(positionsProvider.notifier).refresh();
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          disabledBackgroundColor: buttonColor.withValues(alpha: 0.3),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26.r),
          ),
        ),
        child: tradeState.isSubmitting || phoenixLoading
            ? SizedBox(
                width: 20.w,
                height: 20.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                buttonLabel,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slippage tolerance selector — only shown for market orders
// ---------------------------------------------------------------------------

class TradeSlippageSelector extends ConsumerWidget {
  final TradeState tradeState;
  const TradeSlippageSelector({super.key, required this.tradeState});

  static const _options = [10, 50, 100, 200]; // bps

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Text(
          'Slippage',
          style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12.sp),
        ),
        const Spacer(),
        ..._options.map((bps) {
          final selected = tradeState.slippageBps == bps;
          final label = bps < 100
              ? '${(bps / 100).toStringAsFixed(1)}%'
              : '${(bps / 100).toStringAsFixed(0)}%';
          return GestureDetector(
            onTap: () => ref.read(tradeProvider.notifier).setSlippageBps(bps),
            child: Padding(
              padding: EdgeInsets.only(left: 14.w),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.primary : AppColors.textMutedDark,
                  fontSize: 12.sp,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  decoration: selected
                      ? TextDecoration.underline
                      : TextDecoration.none,
                  decorationColor: AppColors.primary,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
