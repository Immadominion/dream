import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/models/phoenix/phoenix_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../markets/providers/markets_provider.dart';
import '../../providers/trade_provider.dart';
import 'orderbook_widget.dart';

// ---------------------------------------------------------------------------
// Compact Bybit-style orderbook ladder for the Trade page right column.
// Stacked asks ↓ mid-price ↓ bids with depth-bar backgrounds, B/S ratio bar
// and tick-size selector. Borderless — typography + soft fills only.
// ---------------------------------------------------------------------------

const _kRowsPerSide = 7;
const _kTickSizes = [0.1, 0.5, 1.0, 5.0, 10.0];

class TradeCompactOrderbook extends ConsumerStatefulWidget {
  final String symbol;
  const TradeCompactOrderbook({super.key, required this.symbol});

  @override
  ConsumerState<TradeCompactOrderbook> createState() =>
      _TradeCompactOrderbookState();
}

class _TradeCompactOrderbookState
    extends ConsumerState<TradeCompactOrderbook> {
  double _tick = 0.1;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderbookProvider(widget.symbol));
    final ob = state.orderbook;
    final liveMark = ref.watch(marketsProvider).priceFor(widget.symbol);
    final baseSym = widget.symbol.split('-').first;
    final quoteSym = widget.symbol.contains('-')
        ? widget.symbol.split('-').last.replaceAll('PERP', '').toUpperCase()
        : 'USDC';
    final quoteLabel = quoteSym.isEmpty ? 'USDC' : quoteSym;

    if (ob == null) {
      return Center(
        child: Text(
          '…',
          style: TextStyle(color: AppColors.textMutedDark, fontSize: 12.sp),
        ),
      );
    }

    final asks = ob.asks.take(_kRowsPerSide).toList().reversed.toList();
    final bids = ob.bids.take(_kRowsPerSide).toList();
    final maxSize = [
      ...asks.map((l) => l.size),
      ...bids.map((l) => l.size),
    ].fold(0.0, (a, b) => a > b ? a : b);

    final bidVol = bids.fold(0.0, (a, b) => a + b.size);
    final askVol = asks.fold(0.0, (a, b) => a + b.size);
    final totalVol = bidVol + askVol;
    final bidPct = totalVol > 0 ? bidVol / totalVol : 0.5;
    final askPct = 1 - bidPct;

    final mid = liveMark > 0 ? liveMark : (ob.mid ?? (ob.bestBid + ob.bestAsk) / 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(quoteLabel: quoteLabel, baseLabel: baseSym),
        SizedBox(height: 4.h),
        // Asks — reversed so best ask is closest to mid
        for (final lvl in asks)
          _LadderRow(
            level: lvl,
            maxSize: maxSize,
            isBid: false,
            onTap: () => _setPrice(lvl.price),
          ),
        // Mid price
        _MidPriceRow(price: mid),
        // Bids
        for (final lvl in bids)
          _LadderRow(
            level: lvl,
            maxSize: maxSize,
            isBid: true,
            onTap: () => _setPrice(lvl.price),
          ),
        SizedBox(height: 6.h),
        _RatioBar(bidPct: bidPct, askPct: askPct),
        SizedBox(height: 6.h),
        _TickAndLayoutRow(
          tick: _tick,
          onTickChanged: (v) => setState(() => _tick = v),
        ),
      ],
    );
  }

  void _setPrice(double price) {
    final notifier = ref.read(tradeProvider.notifier);
    notifier.setOrderType(OrderType.limit);
    notifier.setPrice(price);
  }
}

// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final String quoteLabel;
  final String baseLabel;
  const _Header({required this.quoteLabel, required this.baseLabel});

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textMutedDark;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: muted, fontSize: 10.sp),
                children: [
                  const TextSpan(text: 'Price '),
                  TextSpan(text: '($quoteLabel)'),
                ],
              ),
            ),
          ),
          RichText(
            textAlign: TextAlign.right,
            text: TextSpan(
              style: TextStyle(color: muted, fontSize: 10.sp),
              children: [
                const TextSpan(text: 'Qty '),
                TextSpan(text: '($baseLabel)'),
              ],
            ),
          ),
          SizedBox(width: 3.w),
          Icon(Icons.arrow_drop_down, size: 14.sp, color: muted),
        ],
      ),
    );
  }
}

class _LadderRow extends StatelessWidget {
  final PhoenixOrderLevel level;
  final double maxSize;
  final bool isBid;
  final VoidCallback onTap;

  const _LadderRow({
    required this.level,
    required this.maxSize,
    required this.isBid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isBid ? AppColors.bullish : AppColors.bearish;
    final pct = maxSize > 0 ? (level.size / maxSize).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 20.h,
        child: Stack(
          children: [
            // Depth bar — fill the row, align bar to the right edge
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: pct,
                  heightFactor: 1,
                  child: Container(color: color.withAlpha(38)),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.w),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _fmtPrice(level.price),
                      style: TextStyle(
                        color: color,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Text(
                    _fmtSize(level.size),
                    style: TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontSize: 11.sp,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MidPriceRow extends StatelessWidget {
  final double price;
  const _MidPriceRow({required this.price});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(6.w, 4.h, 6.w, 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fmtPrice(price),
                  style: TextStyle(
                    color: AppColors.bullish,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  '≈${_fmtPrice(price)} USD',
                  style: TextStyle(
                    color: AppColors.textMutedDark,
                    fontSize: 9.sp,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward,
            size: 14.sp,
            color: AppColors.textMutedDark,
          ),
        ],
      ),
    );
  }
}

class _RatioBar extends StatelessWidget {
  final double bidPct;
  final double askPct;
  const _RatioBar({required this.bidPct, required this.askPct});

  @override
  Widget build(BuildContext context) {
    final bidLabel = '${(bidPct * 100).round()}%';
    final askLabel = '${(askPct * 100).round()}%';
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      child: SizedBox(
        height: 18.h,
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(right: 4.w),
              child: Text(
                'B',
                style: TextStyle(
                  color: AppColors.bullish,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              flex: (bidPct * 1000).round().clamp(1, 999),
              child: Container(
                height: 16.h,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.bullish.withAlpha(40),
                  borderRadius: BorderRadius.horizontal(left: Radius.circular(2.r)),
                ),
                child: Text(
                  bidLabel,
                  style: TextStyle(
                    color: AppColors.bullish,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: (askPct * 1000).round().clamp(1, 999),
              child: Container(
                height: 16.h,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.bearish.withAlpha(40),
                  borderRadius: BorderRadius.horizontal(right: Radius.circular(2.r)),
                ),
                child: Text(
                  askLabel,
                  style: TextStyle(
                    color: AppColors.bearish,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 4.w),
              child: Text(
                'S',
                style: TextStyle(
                  color: AppColors.bearish,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TickAndLayoutRow extends StatelessWidget {
  final double tick;
  final ValueChanged<double> onTickChanged;
  const _TickAndLayoutRow({required this.tick, required this.onTickChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<double>(
                value: tick,
                isDense: true,
                isExpanded: true,
                dropdownColor: AppColors.surfaceDark,
                icon: Icon(
                  Icons.arrow_drop_down,
                  size: 16.sp,
                  color: AppColors.textMutedDark,
                ),
                style: TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 11.sp,
                ),
                items: _kTickSizes
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(_fmtTick(t)),
                        ))
                    .toList(),
                onChanged: (v) => v == null ? null : onTickChanged(v),
              ),
            ),
          ),
          SizedBox(width: 6.w),
          Icon(
            Icons.view_agenda_outlined,
            size: 16.sp,
            color: AppColors.textMutedDark,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

String _fmtTick(double t) {
  if (t >= 1) return t.toStringAsFixed(0);
  return t.toString();
}

String _fmtPrice(double price) {
  if (price >= 10000) return addThousandsSep(price.toStringAsFixed(0));
  if (price >= 1000) {
    final parts = price.toStringAsFixed(1).split('.');
    return '${addThousandsSep(parts[0])}.${parts[1]}';
  }
  if (price >= 100) return price.toStringAsFixed(2);
  if (price >= 1) return price.toStringAsFixed(3);
  return price.toStringAsFixed(4);
}

String _fmtSize(double size) {
  if (size <= 0) return '--';
  if (size >= 1000) return '${(size / 1000).toStringAsFixed(2)}K';
  if (size >= 100) return size.toStringAsFixed(2);
  if (size >= 1) return size.toStringAsFixed(3);
  return size.toStringAsFixed(4);
}
