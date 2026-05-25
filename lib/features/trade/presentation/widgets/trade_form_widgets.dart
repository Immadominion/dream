import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/trade_provider.dart';

// ---------------------------------------------------------------------------
// Bybit-style trade form primitives.
// Borderless filled inputs with INLINE floating labels, pill Buy/Sell toggle,
// dropdown order type, segmented leverage slider.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Buy / Sell pill toggle — single rounded container, soft fill on active half
// ---------------------------------------------------------------------------

class TradeSideToggle extends ConsumerWidget {
  final TradeState tradeState;
  const TradeSideToggle({super.key, required this.tradeState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLong = tradeState.side == OrderSide.buy;
    return Container(
      height: 36.h,
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(18.r),
      ),
      padding: EdgeInsets.all(2.r),
      child: Row(
        children: [
          Expanded(
            child: _PillSide(
              label: 'Buy',
              selected: isLong,
              color: AppColors.bullish,
              onTap: () =>
                  ref.read(tradeProvider.notifier).setSide(OrderSide.buy),
            ),
          ),
          Expanded(
            child: _PillSide(
              label: 'Sell',
              selected: !isLong,
              color: AppColors.bearish,
              onTap: () =>
                  ref.read(tradeProvider.notifier).setSide(OrderSide.sell),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillSide extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _PillSide({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(16.r),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : AppColors.textSecondaryDark,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Order type — Limit / Market dropdown (borderless filled)
// ---------------------------------------------------------------------------

class TradeOrderTypeToggle extends ConsumerWidget {
  final TradeState tradeState;
  const TradeOrderTypeToggle({super.key, required this.tradeState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label =
        tradeState.orderType == OrderType.market ? 'Market' : 'Limit';
    return PopupMenuButton<OrderType>(
      initialValue: tradeState.orderType,
      onSelected: (v) => ref.read(tradeProvider.notifier).setOrderType(v),
      color: AppColors.surfaceDark,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6.r),
        side: BorderSide(color: AppColors.borderDark),
      ),
      padding: EdgeInsets.zero,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: OrderType.market,
          height: 36.h,
          child: Text(
            'Market',
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 13.sp,
            ),
          ),
        ),
        PopupMenuItem(
          value: OrderType.limit,
          height: 36.h,
          child: Text(
            'Limit',
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 13.sp,
            ),
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: 2.w),
          Icon(
            Icons.expand_more_rounded,
            size: 16.sp,
            color: AppColors.textMutedDark,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Limit price input — inline floating label "Price", suffix "USDC"
// ---------------------------------------------------------------------------

class TradePriceInput extends ConsumerStatefulWidget {
  final TradeState tradeState;
  const TradePriceInput({super.key, required this.tradeState});

  @override
  ConsumerState<TradePriceInput> createState() => _TradePriceInputState();
}

class _TradePriceInputState extends ConsumerState<TradePriceInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.tradeState.price > 0
          ? widget.tradeState.price.toString()
          : '',
    );
  }

  @override
  void didUpdateWidget(covariant TradePriceInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next =
        widget.tradeState.price > 0 ? widget.tradeState.price.toString() : '';
    if (next != _ctrl.text && next.isNotEmpty) {
      _ctrl.text = next;
      _ctrl.selection =
          TextSelection.fromPosition(TextPosition(offset: next.length));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44.h,
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Price',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 12.sp,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) {
                final d = double.tryParse(v);
                if (d != null) ref.read(tradeProvider.notifier).setPrice(d);
              },
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            'USDC',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Leverage selector — Bybit-style segmented slider
// ---------------------------------------------------------------------------

class TradeLeverageSelector extends ConsumerWidget {
  final TradeState tradeState;
  const TradeLeverageSelector({super.key, required this.tradeState});

  static const _levels = [1.0, 2.0, 5.0, 10.0, 20.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = tradeState.leverage;
    int idx = _levels.indexWhere((l) => l >= current);
    if (idx < 0) idx = _levels.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Leverage',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 12.sp,
              ),
            ),
            const Spacer(),
            Text(
              '${_levels[idx].toInt()}×',
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2.h,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.cardDark,
            thumbColor: AppColors.textPrimaryDark,
            overlayColor: AppColors.primary.withValues(alpha: 0.12),
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7.r),
            tickMarkShape: RoundSliderTickMarkShape(tickMarkRadius: 3.r),
            activeTickMarkColor: AppColors.primary,
            inactiveTickMarkColor: AppColors.borderDark,
          ),
          child: Slider(
            value: idx.toDouble(),
            min: 0,
            max: (_levels.length - 1).toDouble(),
            divisions: _levels.length - 1,
            onChanged: (v) => ref
                .read(tradeProvider.notifier)
                .setLeverage(_levels[v.round()]),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Borderless inline numeric field — Price / Quantity / Order Value
// ---------------------------------------------------------------------------

class TradeInlineNumericField extends StatefulWidget {
  final String label;
  final String? suffix;
  final String? initialValue;
  final TextEditingController? controller;
  final ValueChanged<String> onChanged;
  final bool readOnly;
  final Widget? trailing;

  const TradeInlineNumericField({
    super.key,
    required this.label,
    required this.onChanged,
    this.suffix,
    this.initialValue,
    this.controller,
    this.readOnly = false,
    this.trailing,
  });

  @override
  State<TradeInlineNumericField> createState() =>
      _TradeInlineNumericFieldState();
}

class _TradeInlineNumericFieldState extends State<TradeInlineNumericField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _ctrl = widget.controller!;
    } else {
      _ctrl = TextEditingController(text: widget.initialValue);
      _ownsController = true;
    }
    _focus = FocusNode();
    _focus.addListener(() => setState(() {}));
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    if (_ownsController) _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = _ctrl.text.isNotEmpty;
    final showLabelTop = _focus.hasFocus || hasValue;

    return Container(
      height: 52.h,
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            left: 0,
            top: showLabelTop ? 6.h : 16.h,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              style: TextStyle(
                color: AppColors.textMutedDark,
                fontSize: showLabelTop ? 10.sp : 14.sp,
                fontWeight: FontWeight.w500,
              ),
              child: Text(widget.label),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 14.h),
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    readOnly: widget.readOnly,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    style: TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: widget.onChanged,
                  ),
                ),
              ),
              if (widget.suffix != null)
                Padding(
                  padding: EdgeInsets.only(left: 8.w, top: 14.h),
                  child: Text(
                    widget.suffix!,
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              if (widget.trailing != null) ...[
                SizedBox(width: 6.w),
                Padding(
                  padding: EdgeInsets.only(top: 14.h),
                  child: widget.trailing!,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Post-only checkbox row — flat, borderless
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
              borderRadius: BorderRadius.circular(3.r),
              border: Border.all(
                color: enabled ? AppColors.primary : AppColors.textMutedDark,
                width: 1.4,
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
            ),
          ),
          const Spacer(),
          Text(
            'GTC',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
