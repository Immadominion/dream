import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/models/phoenix/phoenix_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../markets/providers/markets_provider.dart';
import '../../providers/trade_provider.dart';
import '../../../alerts/presentation/widgets/price_alert_button.dart';

// ---------------------------------------------------------------------------
// Market header — symbol selector, live price, change %, stat strip
// ---------------------------------------------------------------------------

class TradeMarketHeader extends ConsumerWidget {
  final TradeState tradeState;
  final MarketsState marketsState;

  const TradeMarketHeader({
    super.key,
    required this.tradeState,
    required this.marketsState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = marketsState.priceFor(tradeState.symbol);
    final snapshot = marketsState.snapshots[tradeState.symbol];
    final change = marketsState.changeFor(tradeState.symbol);
    final isPositive = change >= 0;
    final changeColor = isPositive ? AppColors.bullish : AppColors.bearish;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(
          bottom: BorderSide(color: AppColors.borderDark, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          // Row 1: symbol + price + change
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
            child: Row(
              children: [
                // Symbol selector
                GestureDetector(
                  onTap: () => _showSymbolPicker(context, ref),
                  child: Row(
                    children: [
                      Text(
                        tradeState.symbol,
                        style: TextStyle(
                          color: AppColors.textPrimaryDark,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.textSecondaryDark,
                        size: 16.sp,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                PriceAlertButton(symbol: tradeState.symbol),
                SizedBox(width: 12.w),
                // Live price
                Text(
                  formatPrice(price),
                  style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                SizedBox(width: 6.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: changeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    formatPercent(change),
                    style: TextStyle(
                      color: changeColor,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Row 2: stat strip (funding, 24H H/L, volume)
          if (snapshot != null)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 10.h),
              child: Row(
                children: [
                  _StatChip(
                    label: 'Fund',
                    value: formatFundingRate(snapshot.fundingRate),
                    valueColor: snapshot.fundingRate >= 0
                        ? AppColors.bullish
                        : AppColors.bearish,
                  ),
                  SizedBox(width: 16.w),
                  _StatChip(
                    label: '24H H',
                    value: formatPrice(snapshot.high24h),
                  ),
                  SizedBox(width: 16.w),
                  _StatChip(
                    label: '24H L',
                    value: formatPrice(snapshot.low24h),
                  ),
                  SizedBox(width: 16.w),
                  _StatChip(
                    label: 'Vol',
                    value: formatCompact(snapshot.volume24hUsd),
                  ),
                ],
              ),
            )
          else
            SizedBox(height: 10.h),
        ],
      ),
    );
  }

  void _showSymbolPicker(BuildContext context, WidgetRef ref) {
    final markets = ref.read(marketsProvider).markets;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) => _SymbolPickerSheet(
        markets: markets,
        onSelect: (symbol) {
          ref.read(tradeProvider.notifier).selectSymbol(symbol);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat chip (label + value, used in stat strip)
// ---------------------------------------------------------------------------

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _StatChip({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textMutedDark, fontSize: 9.sp),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textSecondaryDark,
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Symbol picker bottom sheet — searchable market list
// ---------------------------------------------------------------------------

class _SymbolPickerSheet extends StatefulWidget {
  final List<PhoenixMarket> markets;
  final ValueChanged<String> onSelect;

  const _SymbolPickerSheet({required this.markets, required this.onSelect});

  @override
  State<_SymbolPickerSheet> createState() => _SymbolPickerSheetState();
}

class _SymbolPickerSheetState extends State<_SymbolPickerSheet> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.markets.where((m) {
      if (_query.isEmpty) return true;
      return m.symbol.toLowerCase().contains(_query.toLowerCase()) ||
          m.baseAsset.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: EdgeInsets.only(top: 10.h, bottom: 8.h),
          width: 36.w,
          height: 4.h,
          decoration: BoxDecoration(
            color: AppColors.borderDark,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            'Select Market',
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(height: 12.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            style: TextStyle(color: AppColors.textPrimaryDark, fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: 'Search markets…',
              hintStyle: TextStyle(
                color: AppColors.textMutedDark,
                fontSize: 14.sp,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: AppColors.textMutedDark,
                size: 18.sp,
              ),
              suffixIcon: _query.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _ctrl.clear();
                        setState(() => _query = '');
                      },
                      child: Icon(
                        Icons.close,
                        color: AppColors.textMutedDark,
                        size: 16.sp,
                      ),
                    )
                  : null,
              filled: true,
              fillColor: AppColors.cardDark,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 10.h,
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
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        SizedBox(height: 8.h),
        Flexible(
          child: filtered.isEmpty
              ? Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.h),
                  child: Text(
                    'No markets found',
                    style: TextStyle(
                      color: AppColors.textMutedDark,
                      fontSize: 13.sp,
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final m = filtered[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
                      title: Text(
                        m.symbol,
                        style: TextStyle(
                          color: AppColors.textPrimaryDark,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        m.baseAsset,
                        style: TextStyle(
                          color: AppColors.textMutedDark,
                          fontSize: 11.sp,
                        ),
                      ),
                      onTap: () => widget.onSelect(m.symbol),
                    );
                  },
                ),
        ),
        SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16.h),
      ],
    );
  }
}
