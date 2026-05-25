import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../providers/trade_provider.dart';

// ---------------------------------------------------------------------------
// Take Profit / Stop Loss expandable section — with % shortcuts + validation
// ---------------------------------------------------------------------------

class TradeTpSlSection extends ConsumerStatefulWidget {
  final TradeState tradeState;
  const TradeTpSlSection({super.key, required this.tradeState});

  @override
  ConsumerState<TradeTpSlSection> createState() => TradeTpSlSectionState();
}

class TradeTpSlSectionState extends ConsumerState<TradeTpSlSection> {
  final _slCtrl = TextEditingController();
  final _tpCtrl = TextEditingController();

  @override
  void dispose() {
    _slCtrl.dispose();
    _tpCtrl.dispose();
    super.dispose();
  }

  // Only sync when the field is not focused (avoids cursor jumping mid-edit)
  void _syncControllers(TradeState s) {
    final slText = s.stopLossPrice != null
        ? s.stopLossPrice!.toStringAsFixed(2)
        : '';
    if (!_slCtrl.selection.isValid && _slCtrl.text != slText) {
      _slCtrl.text = slText;
    }
    final tpText = s.takeProfitPrice != null
        ? s.takeProfitPrice!.toStringAsFixed(2)
        : '';
    if (!_tpCtrl.selection.isValid && _tpCtrl.text != tpText) {
      _tpCtrl.text = tpText;
    }
  }

  /// Apply a percentage offset to the mark price and set TP or SL accordingly.
  void _applyPct({required double pctOffset, required bool isTp}) {
    final mark = widget.tradeState.markPrice;
    if (mark <= 0) return;
    final price = mark * (1 + pctOffset / 100);
    final notifier = ref.read(tradeProvider.notifier);
    final text = price.toStringAsFixed(2);
    if (isTp) {
      _tpCtrl.text = text;
      notifier.setTakeProfitPrice(price);
    } else {
      _slCtrl.text = text;
      notifier.setStopLossPrice(price);
    }
  }

  /// Validate TP/SL against side + mark price. Returns null when valid.
  ({String? tp, String? sl}) _validate(TradeState s) {
    final mark = s.markPrice;
    final isLong = s.side == OrderSide.buy;
    String? tpErr, slErr;

    if (s.takeProfitPrice != null && mark > 0) {
      if (isLong && s.takeProfitPrice! <= mark) {
        tpErr = 'TP should be above mark (long)';
      } else if (!isLong && s.takeProfitPrice! >= mark) {
        tpErr = 'TP should be below mark (short)';
      }
    }
    if (s.stopLossPrice != null && mark > 0) {
      if (isLong && s.stopLossPrice! >= mark) {
        slErr = 'SL should be below mark (long)';
      } else if (!isLong && s.stopLossPrice! <= mark) {
        slErr = 'SL should be above mark (short)';
      }
    }
    return (tp: tpErr, sl: slErr);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.tradeState;
    final notifier = ref.read(tradeProvider.notifier);
    final isLong = s.side == OrderSide.buy;

    if (s.tpSlEnabled) _syncControllers(s);

    final errors = s.tpSlEnabled ? _validate(s) : (tp: null, sl: null);

    // Percentage shortcuts differ by side:
    // TP: positive offset for longs (+), negative for shorts (-)
    // SL: negative offset for longs (-), positive for shorts (+)
    final tpPcts = isLong ? [2.5, 5.0, 10.0] : [-2.5, -5.0, -10.0];
    final slPcts = isLong ? [-2.5, -5.0, -10.0] : [2.5, 5.0, 10.0];

    return Column(
      children: [
        // Toggle row
        GestureDetector(
          onTap: () => notifier.toggleTpSl(!s.tpSlEnabled),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Icon(
                Icons.flag_outlined,
                size: 14.sp,
                color: s.tpSlEnabled
                    ? AppColors.primary
                    : AppColors.textMutedDark,
              ),
              SizedBox(width: 6.w),
              Text(
                'TP / SL',
                style: TextStyle(
                  color: s.tpSlEnabled
                      ? AppColors.textPrimaryDark
                      : AppColors.textSecondaryDark,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              _TinySwitch(value: s.tpSlEnabled, onChanged: notifier.toggleTpSl),
            ],
          ),
        ),

        // Expanded inputs — only when enabled
        if (s.tpSlEnabled) ...[
          SizedBox(height: 10.h),
          Padding(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mark price context row
                if (s.markPrice > 0) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 12.r,
                        color: AppColors.textMutedDark,
                      ),
                      SizedBox(width: 4.w),
                      Flexible(
                        child: Text(
                          'Mark: ${formatPrice(s.markPrice)}  •  '
                          '${isLong ? 'Long' : 'Short'}: TP ${isLong ? 'above' : 'below'}, SL ${isLong ? 'below' : 'above'}',
                          style: TextStyle(
                            color: AppColors.textMutedDark,
                            fontSize: 11.sp,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                ],

                // TP + SL fields side by side
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Take Profit ---
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TpSlField(
                            label: 'Take Profit \$',
                            controller: _tpCtrl,
                            labelColor: AppColors.bullish,
                            onChanged: (v) =>
                                notifier.setTakeProfitPrice(double.tryParse(v)),
                          ),
                          SizedBox(height: 6.h),
                          _PctShortcuts(
                            pcts: tpPcts,
                            accentColor: AppColors.bullish,
                            onSelect: (pct) =>
                                _applyPct(pctOffset: pct, isTp: true),
                          ),
                          if (errors.tp != null) ...[
                            SizedBox(height: 4.h),
                            _ValidationNote(message: errors.tp!),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: 12.w),
                    // --- Stop Loss ---
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TpSlField(
                            label: 'Stop Loss \$',
                            controller: _slCtrl,
                            labelColor: AppColors.bearish,
                            onChanged: (v) =>
                                notifier.setStopLossPrice(double.tryParse(v)),
                          ),
                          SizedBox(height: 6.h),
                          _PctShortcuts(
                            pcts: slPcts,
                            accentColor: AppColors.bearish,
                            onSelect: (pct) =>
                                _applyPct(pctOffset: pct, isTp: false),
                          ),
                          if (errors.sl != null) ...[
                            SizedBox(height: 4.h),
                            _ValidationNote(message: errors.sl!),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tiny custom switch — avoids Switch.adaptive 60px minimum width
// ---------------------------------------------------------------------------

class _TinySwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _TinySwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 32.w,
        height: 18.h,
        padding: EdgeInsets.all(2.r),
        decoration: BoxDecoration(
          color: value ? AppColors.primary : AppColors.borderDark,
          borderRadius: BorderRadius.circular(9.r),
        ),
        child: Align(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 14.r,
            height: 14.r,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Percentage shortcut chips row
// ---------------------------------------------------------------------------

class _PctShortcuts extends StatelessWidget {
  final List<double> pcts;
  final Color accentColor;
  final ValueChanged<double> onSelect;

  const _PctShortcuts({
    required this.pcts,
    required this.accentColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: pcts.map((pct) {
        final label =
            '${pct > 0 ? '+' : ''}${pct.toStringAsFixed(pct.truncateToDouble() == pct ? 0 : 1)}%';
        final isLast = pct == pcts.last;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(pct),
            child: Container(
              margin: EdgeInsets.only(right: isLast ? 0 : 3.w),
              height: 22.h,
              color: accentColor.withValues(alpha: 0.10),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Inline validation note
// ---------------------------------------------------------------------------

class _ValidationNote extends StatelessWidget {
  final String message;
  const _ValidationNote({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.warning_amber_rounded, size: 11.r, color: AppColors.bearish),
        SizedBox(width: 3.w),
        Flexible(
          child: Text(
            message,
            style: TextStyle(color: AppColors.bearish, fontSize: 10.sp),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// TP / SL price text field (label-coloured border on focus)
// ---------------------------------------------------------------------------

class _TpSlField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Color labelColor;
  final ValueChanged<String> onChanged;

  const _TpSlField({
    required this.label,
    required this.controller,
    required this.labelColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 6.h),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          style: TextStyle(
            color: AppColors.textPrimaryDark,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: '0.00',
            hintStyle: TextStyle(
              color: AppColors.textMutedDark,
              fontSize: 14.sp,
            ),
            filled: true,
            fillColor: AppColors.surfaceDark,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 10.w,
              vertical: 10.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.r),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.r),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.r),
              borderSide: BorderSide(color: labelColor, width: 1.2),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
