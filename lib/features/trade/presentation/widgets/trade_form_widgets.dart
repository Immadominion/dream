import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/trade_provider.dart';

// ---------------------------------------------------------------------------
// Long / Short side toggle
// ---------------------------------------------------------------------------

class TradeSideToggle extends ConsumerWidget {
  final TradeState tradeState;
  const TradeSideToggle({super.key, required this.tradeState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLong = tradeState.side == OrderSide.buy;
    return Row(
      children: [
        Expanded(
          child: _ToggleButton(
            label: 'Long',
            selected: isLong,
            selectedColor: AppColors.bullish,
            onTap: () =>
                ref.read(tradeProvider.notifier).setSide(OrderSide.buy),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _ToggleButton(
            label: 'Short',
            selected: !isLong,
            selectedColor: AppColors.bearish,
            onTap: () =>
                ref.read(tradeProvider.notifier).setSide(OrderSide.sell),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Market / Limit order type toggle
// ---------------------------------------------------------------------------

class TradeOrderTypeToggle extends ConsumerWidget {
  final TradeState tradeState;
  const TradeOrderTypeToggle({super.key, required this.tradeState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMarket = tradeState.orderType == OrderType.market;
    return Row(
      children: [
        Expanded(
          child: _ToggleButton(
            label: 'Market',
            selected: isMarket,
            selectedColor: AppColors.primary,
            onTap: () =>
                ref.read(tradeProvider.notifier).setOrderType(OrderType.market),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _ToggleButton(
            label: 'Limit',
            selected: !isMarket,
            selectedColor: AppColors.primary,
            onTap: () =>
                ref.read(tradeProvider.notifier).setOrderType(OrderType.limit),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Limit price input
// ---------------------------------------------------------------------------

class TradePriceInput extends ConsumerWidget {
  final TradeState tradeState;
  const TradePriceInput({super.key, required this.tradeState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _NumericField(
      label: 'Limit Price (USD)',
      hint: '0.00',
      initialValue: tradeState.price > 0 ? tradeState.price.toString() : null,
      suffix: 'USD',
      onChanged: (v) {
        final d = double.tryParse(v);
        if (d != null) ref.read(tradeProvider.notifier).setPrice(d);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Leverage selector — preset chips
// ---------------------------------------------------------------------------

class TradeLeverageSelector extends ConsumerWidget {
  final TradeState tradeState;
  const TradeLeverageSelector({super.key, required this.tradeState});

  static const _levels = [1.0, 2.0, 3.0, 5.0, 10.0, 20.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = tradeState.leverage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Leverage',
          style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12.sp),
        ),
        SizedBox(height: 6.h),
        Row(
          children: _levels.map((lev) {
            final selected = current == lev;
            return Expanded(
              child: GestureDetector(
                onTap: () => ref.read(tradeProvider.notifier).setLeverage(lev),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: EdgeInsets.only(right: lev == _levels.last ? 0 : 6.w),
                  height: 34.h,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.cardDark,
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : AppColors.borderDark,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${lev.toInt()}x',
                    style: TextStyle(
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondaryDark,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared numeric text field (label + text input)
// ---------------------------------------------------------------------------

class _NumericField extends StatelessWidget {
  final String label;
  final String hint;
  final String? suffix;
  final String? initialValue;
  final ValueChanged<String> onChanged;

  const _NumericField({
    required this.label,
    required this.hint,
    required this.onChanged,
    this.suffix,
    this.initialValue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12.sp),
        ),
        SizedBox(height: 6.h),
        TextFormField(
          initialValue: initialValue,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          style: TextStyle(color: AppColors.textPrimaryDark, fontSize: 15.sp),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textMutedDark,
              fontSize: 15.sp,
            ),
            suffixText: suffix,
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
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable toggle button (used by side toggle + order type toggle)
// ---------------------------------------------------------------------------

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 40.h,
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withValues(alpha: 0.15)
              : AppColors.cardDark,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: selected ? selectedColor : AppColors.borderDark,
            width: selected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? selectedColor : AppColors.textSecondaryDark,
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Post-only toggle — shown below order type selector for limit orders.
// When enabled the order is only placed if it would be a maker (no crossing).
// ---------------------------------------------------------------------------

class TradePostOnlyToggle extends ConsumerWidget {
  final TradeState tradeState;
  const TradePostOnlyToggle({super.key, required this.tradeState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = tradeState.postOnly;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ref.read(tradeProvider.notifier).togglePostOnly(!enabled),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 16.r,
            height: 16.r,
            decoration: BoxDecoration(
              color: enabled ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(4.r),
              border: Border.all(
                color: enabled ? AppColors.primary : AppColors.borderDark,
                width: 1.5,
              ),
            ),
            child: enabled
                ? Icon(Icons.check, size: 11.r, color: Colors.white)
                : null,
          ),
          SizedBox(width: 8.w),
          Text(
            'Post-Only',
            style: TextStyle(
              color: enabled
                  ? AppColors.textPrimaryDark
                  : AppColors.textSecondaryDark,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 4.w),
          Tooltip(
            message:
                'Order cancelled if it would immediately fill (maker-only)',
            triggerMode: TooltipTriggerMode.tap,
            child: Icon(
              Icons.info_outline,
              size: 13.r,
              color: AppColors.textMutedDark,
            ),
          ),
        ],
      ),
    );
  }
}
