import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/models/phoenix/phoenix_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../markets/providers/markets_provider.dart';
import '../../../positions/providers/positions_provider.dart';
import 'pnl_share_card.dart';

// ---------------------------------------------------------------------------
// Position card — live PnL, funding rate, partial close sheet
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Position card — live PnL, funding rate, partial close sheet
// ---------------------------------------------------------------------------

class PositionCard extends ConsumerStatefulWidget {
  final PhoenixPosition position;

  const PositionCard({super.key, required this.position});

  @override
  ConsumerState<PositionCard> createState() => _PositionCardState();
}

class _PositionCardState extends ConsumerState<PositionCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final marketsState = ref.watch(marketsProvider);
    final livePrice = marketsState.priceFor(widget.position.symbol);
    final markPrice = livePrice > 0 ? livePrice : widget.position.markPrice;

    final livePnl = livePrice > 0
        ? _computeLivePnl(livePrice)
        : widget.position.unrealizedPnl;
    final pnlPct = widget.position.collateral > 0
        ? (livePnl / widget.position.collateral) * 100
        : widget.position.unrealizedPnlPercent;
    final pnlColor = livePnl >= 0 ? AppColors.bullish : AppColors.bearish;
    final sideColor = widget.position.side == 'long'
        ? AppColors.bullish
        : AppColors.bearish;

    // Live liq estimate — falls back to stored value before WS is ready
    final liqPrice = livePrice > 0
        ? _estimateLiqPrice()
        : widget.position.liquidationPrice;

    // Funding APR from live market snapshot
    final hourlyFunding = marketsState.fundingFor(widget.position.symbol);
    final annualFunding = hourlyFunding * 24 * 365 * 100;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: EdgeInsets.only(bottom: 8.h, top: 8.h),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: AppColors.borderDark.withValues(alpha: 0.5),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.r),
            child: Column(
              children: [
                // Collapsed header row
                InkWell(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20.r),
                    topRight: Radius.circular(20.r),
                    bottomLeft: Radius.circular(_isExpanded ? 0 : 20.r),
                    bottomRight: Radius.circular(_isExpanded ? 0 : 20.r),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left: symbol + leverage + size
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  widget.position.symbol,
                                  style: TextStyle(
                                    color: AppColors.textPrimaryDark,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                _Badge(
                                  label:
                                      '${widget.position.leverage.toStringAsFixed(widget.position.leverage % 1 == 0 ? 0 : 1)}×',
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              _fmtSize(
                                widget.position.sizeBase,
                                widget.position.symbol,
                              ),
                              style: TextStyle(
                                color: AppColors.textSecondaryDark,
                                fontSize: 10.sp,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Right: PnL + share + chevron
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _fmtPnl(livePnl),
                                      style: TextStyle(
                                        color: pnlColor,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      _fmtPct(pnlPct),
                                      style: TextStyle(
                                        color: pnlColor,
                                        fontSize: 10.sp,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(width: 6.w),
                                PnlShareButton(
                                  position: widget.position,
                                  livePnl: livePnl,
                                  markPrice: markPrice,
                                  iconOnly: true,
                                ),
                                SizedBox(width: 2.w),
                                AnimatedRotation(
                                  turns: _isExpanded ? 0.5 : 0.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    Icons.expand_more_rounded,
                                    color: AppColors.textSecondaryDark,
                                    size: 18.sp,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Expanded details section
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: !_isExpanded
                      ? const SizedBox.shrink()
                      : Column(
                          children: [
                            // Divider
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14.w),
                              child: Divider(
                                color: AppColors.borderDark,
                                height: 1,
                              ),
                            ),
                            SizedBox(height: 8.h),

                            // Row 1: Entry / Mark / Liq
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14.w),
                              child: Row(
                                children: [
                                  _Detail(
                                    label: 'Entry',
                                    value: _fmtPrice(
                                      widget.position.entryPrice,
                                    ),
                                  ),
                                  _Detail(
                                    label: 'Mark',
                                    value: _fmtPrice(markPrice),
                                  ),
                                  _Detail(
                                    label: 'Liq. Price',
                                    value: liqPrice > 0
                                        ? _fmtPrice(liqPrice)
                                        : '--',
                                    valueColor: AppColors.bearish,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 8.h),

                            // Row 2: Collateral / Notional / Funding APR
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14.w),
                              child: Row(
                                children: [
                                  _Detail(
                                    label: 'Collateral',
                                    value:
                                        '\$${widget.position.collateral.toStringAsFixed(2)}',
                                  ),
                                  _Detail(
                                    label: 'Notional',
                                    value:
                                        '\$${widget.position.sizeUsd.toStringAsFixed(2)}',
                                  ),
                                  _Detail(
                                    label: 'Funding APR',
                                    value:
                                        '${annualFunding >= 0 ? '+' : ''}${annualFunding.toStringAsFixed(2)}%',
                                    valueColor: annualFunding >= 0
                                        ? AppColors.bullish
                                        : AppColors.bearish,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 8.h),

                            // Row 3: Accrued / TP / SL
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14.w),
                              child: Row(
                                children: [
                                  _Detail(
                                    label: 'Accrued',
                                    value:
                                        widget.position.accumulatedFunding != 0
                                        ? '${widget.position.accumulatedFunding >= 0 ? '+' : ''}\$${widget.position.accumulatedFunding.abs().toStringAsFixed(2)}'
                                        : '--',
                                    valueColor:
                                        widget.position.accumulatedFunding >= 0
                                        ? AppColors.bullish
                                        : AppColors.bearish,
                                  ),
                                  if (widget.position.takeProfitPrice != null)
                                    _Detail(
                                      label: 'Take Profit',
                                      value: _fmtPrice(
                                        widget.position.takeProfitPrice!,
                                      ),
                                      valueColor: AppColors.bullish,
                                    )
                                  else
                                    const Expanded(child: SizedBox()),
                                  if (widget.position.stopLossPrice != null)
                                    _Detail(
                                      label: 'Stop Loss',
                                      value: _fmtPrice(
                                        widget.position.stopLossPrice!,
                                      ),
                                      valueColor: AppColors.bearish,
                                    )
                                  else
                                    const Expanded(child: SizedBox()),
                                ],
                              ),
                            ),
                            SizedBox(height: 12.h),

                            // Action buttons row
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                14.w,
                                4.h,
                                14.w,
                                14.h,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 32.h,
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _showTpSlSheet(context),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(50),
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: Text(
                                          'TP / SL',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: SizedBox(
                                      height: 32.h,
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _showAddMarginSheet(context),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: AppColors.textMutedDark
                                                .withValues(alpha: 0.4),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(50),
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: Text(
                                          'Add Margin',
                                          style: TextStyle(
                                            color: AppColors.textSecondaryDark,
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: SizedBox(
                                      height: 32.h,
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _showCloseSheet(context, markPrice),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: AppColors.bearish.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(50),
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: Text(
                                          'Close',
                                          style: TextStyle(
                                            color: AppColors.bearish,
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),

        // Overlaid LONG/SHORT badge — stacked on the top-right corner
        Positioned(
          top: 6.h,
          right: -2.w,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: sideColor,
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: sideColor.withValues(alpha: 0.45),
                  blurRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              widget.position.side.toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showTpSlSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (_) => _TpSlSheet(position: widget.position),
    );
  }

  void _showAddMarginSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (_) => _AddMarginSheet(position: widget.position),
    );
  }

  void _showCloseSheet(BuildContext context, double markPrice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (_) =>
          _ClosePositionSheet(position: widget.position, markPrice: markPrice),
    );
  }

  double _computeLivePnl(double liveMarkPrice) {
    final dir = widget.position.side == 'long' ? 1.0 : -1.0;
    return (liveMarkPrice - widget.position.entryPrice) *
        widget.position.sizeBase *
        dir;
  }

  /// Conservative liq estimate: entry ∓ (collateral * 0.95 / sizeBase)
  double _estimateLiqPrice() {
    if (widget.position.sizeBase <= 0 || widget.position.collateral <= 0) {
      return widget.position.liquidationPrice;
    }
    const mm = 0.05; // 5% maintenance margin
    final dir = widget.position.side == 'long' ? 1.0 : -1.0;
    final buffer =
        (widget.position.collateral / widget.position.sizeBase) * (1 - mm);
    return widget.position.entryPrice - dir * buffer;
  }

  String _fmtPnl(double v) {
    final sign = v >= 0 ? '+' : '';
    return '$sign\$${v.abs().toStringAsFixed(2)}';
  }

  String _fmtPct(double v) {
    final sign = v >= 0 ? '+' : '';
    return '$sign${v.toStringAsFixed(2)}%';
  }

  String _fmtPrice(double v) {
    if (v >= 1000) return '\$${v.toStringAsFixed(0)}';
    if (v >= 1) return '\$${v.toStringAsFixed(2)}';
    return '\$${v.toStringAsFixed(4)}';
  }

  String _fmtSize(double size, String symbol) {
    final base = symbol.split('-').first;
    return '${size.toStringAsFixed(4)} $base';
  }
}

// ---------------------------------------------------------------------------
// Partial close bottom sheet
// ---------------------------------------------------------------------------

class _ClosePositionSheet extends ConsumerStatefulWidget {
  final PhoenixPosition position;
  final double markPrice;

  const _ClosePositionSheet({required this.position, required this.markPrice});

  @override
  ConsumerState<_ClosePositionSheet> createState() =>
      _ClosePositionSheetState();
}

class _ClosePositionSheetState extends ConsumerState<_ClosePositionSheet> {
  static const _presets = [25, 50, 75, 100];

  int _pct = 100;
  bool _useCustom = false;
  final _customCtrl = TextEditingController();
  bool _closing = false;

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  double get _closeSize {
    if (_useCustom) {
      final v = double.tryParse(_customCtrl.text) ?? 0;
      return v.clamp(0.0, widget.position.sizeBase);
    }
    return (widget.position.sizeBase * _pct / 100).clamp(
      0.0,
      widget.position.sizeBase,
    );
  }

  double get _estimatedPnl {
    final dir = widget.position.side == 'long' ? 1.0 : -1.0;
    return (widget.markPrice - widget.position.entryPrice) * _closeSize * dir;
  }

  Future<void> _submit() async {
    final size = _closeSize;
    if (size <= 0) return;
    setState(() => _closing = true);
    final error = await ref
        .read(positionsProvider.notifier)
        .closePosition(widget.position, sizeBase: size);
    if (!mounted) return;
    setState(() => _closing = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.bearish),
      );
    } else {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.position.symbol.split('-').first;
    final pnl = _estimatedPnl;
    final pnlColor = pnl >= 0 ? AppColors.bullish : AppColors.bearish;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Container(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 36.w,
                      height: 4.h,
                      margin: EdgeInsets.only(bottom: 16.h),
                      decoration: BoxDecoration(
                        color: AppColors.borderDark,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),

                  Text(
                    'Close ${widget.position.side.toUpperCase()} ${widget.position.symbol}',
                    style: TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Mark price · \$${widget.markPrice >= 1000 ? widget.markPrice.toStringAsFixed(0) : widget.markPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 12.sp,
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // Percentage presets
                  Text(
                    'Close Amount',
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: _presets.map((p) {
                      final sel = !_useCustom && _pct == p;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: p == 100 ? 0 : 8.w),
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _pct = p;
                              _useCustom = false;
                            }),
                            child: Container(
                              height: 38.h,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppColors.bearish.withValues(alpha: 0.15)
                                    : AppColors.surfaceDark,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Text(
                                '$p%',
                                style: TextStyle(
                                  color: sel
                                      ? AppColors.bearish
                                      : AppColors.textSecondaryDark,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  SizedBox(height: 12.h),

                  // Custom size input
                  TextField(
                    controller: _customCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    style: TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontSize: 14.sp,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Custom size',
                      hintStyle: TextStyle(
                        color: AppColors.textMutedDark,
                        fontSize: 13.sp,
                      ),
                      suffixText: base,
                      suffixStyle: TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 13.sp,
                      ),
                      filled: true,
                      fillColor: AppColors.cardDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 10.h,
                      ),
                    ),
                    onChanged: (_) => setState(() => _useCustom = true),
                  ),

                  SizedBox(height: 14.h),

                  // Summary row
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      children: [
                        _SummaryCol(
                          label: 'Close Size',
                          value: '${_closeSize.toStringAsFixed(4)} $base',
                        ),
                        _SummaryCol(
                          label: 'Notional',
                          value:
                              '\$${(_closeSize * widget.markPrice).toStringAsFixed(2)}',
                        ),
                        _SummaryCol(
                          label: 'Est. P&L',
                          value:
                              '${pnl >= 0 ? '+' : ''}\$${pnl.abs().toStringAsFixed(2)}',
                          valueColor: pnlColor,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // Confirm
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: (_closing || _closeSize <= 0) ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.bearish,
                        disabledBackgroundColor: AppColors.bearish.withValues(
                          alpha: 0.3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      child: _closing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _useCustom
                                  ? 'Close ${_closeSize.toStringAsFixed(4)} $base at Market'
                                  : 'Close $_pct% at Market',
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
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit TP/SL sheet
// ---------------------------------------------------------------------------

class _TpSlSheet extends ConsumerStatefulWidget {
  final PhoenixPosition position;
  const _TpSlSheet({required this.position});

  @override
  ConsumerState<_TpSlSheet> createState() => _TpSlSheetState();
}

class _TpSlSheetState extends ConsumerState<_TpSlSheet> {
  final _tpController = TextEditingController();
  final _slController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final pos = widget.position;
    if (pos.takeProfitPrice != null && pos.takeProfitPrice! > 0) {
      _tpController.text = pos.takeProfitPrice!.toStringAsFixed(2);
    }
    if (pos.stopLossPrice != null && pos.stopLossPrice! > 0) {
      _slController.text = pos.stopLossPrice!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _tpController.dispose();
    _slController.dispose();
    super.dispose();
  }

  /// Apply a %-based offset to the reference price and populate the field.
  void _applyPct({required double pctOffset, required bool isTp}) {
    final marketsState = ref.read(marketsProvider);
    final livePrice = marketsState.priceFor(widget.position.symbol);
    final ref0 = livePrice > 0 ? livePrice : widget.position.markPrice;
    if (ref0 <= 0) return;
    final price = ref0 * (1 + pctOffset / 100);
    final text = price.toStringAsFixed(2);
    setState(() {
      if (isTp) {
        _tpController.text = text;
      } else {
        _slController.text = text;
      }
    });
  }

  Future<void> _submit() async {
    final tpText = _tpController.text.trim();
    final slText = _slController.text.trim();
    final tp = tpText.isNotEmpty ? double.tryParse(tpText) : null;
    final sl = slText.isNotEmpty ? double.tryParse(slText) : null;

    if (tpText.isNotEmpty && tp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid take-profit price')),
      );
      return;
    }
    if (slText.isNotEmpty && sl == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid stop-loss price')));
      return;
    }

    // Warn but allow — validation is advisory for experienced traders
    final pos = widget.position;
    final isLong = pos.side == 'long';
    final marketsState = ref.read(marketsProvider);
    final livePrice = marketsState.priceFor(pos.symbol);
    final mark = livePrice > 0 ? livePrice : pos.markPrice;
    if (mark > 0) {
      if (tp != null && isLong && tp <= mark) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Warning: TP is at or below mark price for a long'),
          ),
        );
      }
      if (sl != null && isLong && sl >= mark) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Warning: SL is at or above mark price for a long'),
          ),
        );
      }
      if (tp != null && !isLong && tp >= mark) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Warning: TP is at or above mark price for a short'),
          ),
        );
      }
      if (sl != null && !isLong && sl <= mark) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Warning: SL is at or below mark price for a short'),
          ),
        );
      }
    }

    setState(() => _loading = true);
    final err = await ref
        .read(positionsProvider.notifier)
        .setTpSl(widget.position, takeProfitPrice: tp, stopLossPrice: sl);
    if (!mounted) return;
    setState(() => _loading = false);

    if (err != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $err')));
    } else {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('TP/SL updated')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pos = widget.position;
    final isLong = pos.side == 'long';
    final marketsState = ref.watch(marketsProvider);
    final livePrice = marketsState.priceFor(pos.symbol);
    final mark = livePrice > 0 ? livePrice : pos.markPrice;

    // Shortcuts relative to mark: TP further in profit, SL further in loss
    final tpPcts = isLong ? [2.5, 5.0, 10.0] : [-2.5, -5.0, -10.0];
    final slPcts = isLong ? [-2.5, -5.0, -10.0] : [2.5, 5.0, 10.0];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit TP / SL',
                      style: TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(
                        Icons.close,
                        color: AppColors.textMutedDark,
                        size: 20.r,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  '${pos.symbol}  •  ${pos.side.toUpperCase()}',
                  style: TextStyle(
                    color: AppColors.textMutedDark,
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: 12.h),

                // Entry + mark price context
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    children: [
                      _ContextItem(
                        label: 'Entry',
                        value: _fmtP(pos.entryPrice),
                      ),
                      Container(
                        width: 1,
                        height: 28.h,
                        color: AppColors.borderDark,
                      ),
                      _ContextItem(
                        label: 'Mark',
                        value: mark > 0 ? _fmtP(mark) : '--',
                      ),
                      Container(
                        width: 1,
                        height: 28.h,
                        color: AppColors.borderDark,
                      ),
                      _ContextItem(
                        label: 'Hint',
                        value: isLong ? 'TP ↑  SL ↓' : 'TP ↓  SL ↑',
                        valueColor: AppColors.textSecondaryDark,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),

                // TP input + shortcuts
                _PriceInput(
                  label: 'Take Profit',
                  hint: 'Leave blank to remove',
                  controller: _tpController,
                  accentColor: AppColors.bullish,
                ),
                SizedBox(height: 6.h),
                _ShortcutRow(
                  pcts: tpPcts,
                  accentColor: AppColors.bullish,
                  onSelect: (pct) => _applyPct(pctOffset: pct, isTp: true),
                ),
                SizedBox(height: 14.h),

                // SL input + shortcuts
                _PriceInput(
                  label: 'Stop Loss',
                  hint: 'Leave blank to remove',
                  controller: _slController,
                  accentColor: AppColors.bearish,
                ),
                SizedBox(height: 6.h),
                _ShortcutRow(
                  pcts: slPcts,
                  accentColor: AppColors.bearish,
                  onSelect: (pct) => _applyPct(pctOffset: pct, isTp: false),
                ),
                SizedBox(height: 24.h),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 46.h,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    child: _loading
                        ? SizedBox(
                            width: 18.r,
                            height: 18.r,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Update TP / SL',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtP(double v) {
    if (v >= 1000) return '\$${v.toStringAsFixed(0)}';
    if (v >= 1) return '\$${v.toStringAsFixed(2)}';
    return '\$${v.toStringAsFixed(4)}';
  }
}

// ---------------------------------------------------------------------------
// Add Margin sheet
// ---------------------------------------------------------------------------

class _AddMarginSheet extends ConsumerStatefulWidget {
  final PhoenixPosition position;
  const _AddMarginSheet({required this.position});

  @override
  ConsumerState<_AddMarginSheet> createState() => _AddMarginSheetState();
}

class _AddMarginSheetState extends ConsumerState<_AddMarginSheet> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    final amount = double.tryParse(text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid USDC amount')),
      );
      return;
    }

    setState(() => _loading = true);
    final err = await ref
        .read(positionsProvider.notifier)
        .addCollateral(widget.position, amount);
    if (!mounted) return;
    setState(() => _loading = false);

    if (err != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $err')));
    } else {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added \$${amount.toStringAsFixed(2)} margin')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pos = widget.position;
    final leverage = pos.collateral > 0
        ? (pos.sizeBase * pos.markPrice / pos.collateral)
        : 0.0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add Margin',
                      style: TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(
                        Icons.close,
                        color: AppColors.textMutedDark,
                        size: 20.r,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  '${pos.symbol}  •  Current margin: \$${pos.collateral.toStringAsFixed(2)}  •  ${leverage.toStringAsFixed(1)}x',
                  style: TextStyle(
                    color: AppColors.textMutedDark,
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: 20.h),
                _PriceInput(
                  label: 'Amount (USDC)',
                  hint: 'e.g. 50',
                  controller: _controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  accentColor: AppColors.primary,
                ),
                SizedBox(height: 24.h),
                SizedBox(
                  width: double.infinity,
                  height: 46.h,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    child: _loading
                        ? SizedBox(
                            width: 18.r,
                            height: 18.r,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Add Margin',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ContextItem: compact label + value column used inside _TpSlSheet header
// ---------------------------------------------------------------------------

class _ContextItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _ContextItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: AppColors.textMutedDark, fontSize: 10.sp),
            ),
            SizedBox(height: 2.h),
            Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.textPrimaryDark,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ShortcutRow: quick % chips for TP/SL sheet
// ---------------------------------------------------------------------------

class _ShortcutRow extends StatelessWidget {
  final List<double> pcts;
  final Color accentColor;
  final ValueChanged<double> onSelect;

  const _ShortcutRow({
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
        return Padding(
          padding: EdgeInsets.only(right: pct == pcts.last ? 0 : 6.w),
          child: GestureDetector(
            onTap: () => onSelect(pct),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
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
// Shared price input field
// ---------------------------------------------------------------------------

class _PriceInput extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final Color accentColor;
  final TextInputType keyboardType;

  const _PriceInput({
    required this.label,
    required this.hint,
    required this.controller,
    required this.accentColor,
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 6.h),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(color: AppColors.textPrimaryDark, fontSize: 14.sp),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textMutedDark,
              fontSize: 13.sp,
            ),
            filled: true,
            fillColor: AppColors.cardDark,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: accentColor),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14.w,
              vertical: 12.h,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Summary column widget used in the close sheet
// ---------------------------------------------------------------------------

class _SummaryCol extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryCol({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 10.sp,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimaryDark,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared sub-widgets
// ---------------------------------------------------------------------------

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _Detail({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 10.sp,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimaryDark,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
