import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/models/phoenix/phoenix_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../providers/markets_provider.dart';
import '../../providers/watchlist_provider.dart';
import '../../../positions/providers/positions_provider.dart';

class MarketTile extends ConsumerWidget {
  final PhoenixMarket market;
  final VoidCallback? onTap;

  const MarketTile({super.key, required this.market, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marketsState = ref.watch(marketsProvider);
    final price = marketsState.priceFor(market.symbol);
    final change = marketsState.changeFor(market.symbol);
    final funding = marketsState.fundingFor(market.symbol);
    final snapshot = marketsState.snapshots[market.symbol];

    // Watchlist state
    final isWatched = ref.watch(
      watchlistProvider.select((s) => s.contains(market.symbol)),
    );

    // Open position check
    final positions = ref.watch(positionsProvider).positions;
    final position = positions
        .where((p) => p.symbol == market.symbol)
        .firstOrNull;
    final hasPosition = position != null;
    final posIsLong = hasPosition && position.side.toLowerCase() == 'long';
    final posColor = posIsLong ? AppColors.bullish : AppColors.bearish;
    final posPnl = position?.unrealizedPnl ?? 0.0;

    final isPositive = change >= 0;
    final changeColor = isPositive ? AppColors.bullish : AppColors.bearish;
    final changePrefix = isPositive ? '+' : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 4.w, 14.h),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.borderDark, width: 0.5),
          ),
          color: hasPosition ? posColor.withOpacity(0.04) : Colors.transparent,
        ),
        child: Row(
          children: [
            // Symbol avatar with optional position dot
            _SymbolAvatar(
              symbol: market.baseAsset,
              positionColor: hasPosition ? posColor : null,
            ),
            SizedBox(width: 12.w),

            // Name + funding + vol/OI
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    market.symbol,
                    style: TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Funding ${formatFundingRate(funding)}',
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 11.sp,
                    ),
                  ),
                  // Position P&L row shown when user holds a position here
                  if (hasPosition) ...[
                    SizedBox(height: 3.h),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4.w,
                            vertical: 1.h,
                          ),
                          decoration: BoxDecoration(
                            color: posColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(3.r),
                          ),
                          child: Text(
                            posIsLong ? 'LONG' : 'SHORT',
                            style: TextStyle(
                              color: posColor,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          formatPnl(posPnl),
                          style: TextStyle(
                            color: posPnl >= 0
                                ? AppColors.bullish
                                : AppColors.bearish,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (snapshot != null &&
                      (snapshot.volume24hUsd > 0 ||
                          snapshot.openInterestUsd > 0)) ...[
                    SizedBox(height: 2.h),
                    Text(
                      'Vol ${formatCompact(snapshot.volume24hUsd)}  ·  OI ${formatCompact(snapshot.openInterestUsd)}',
                      style: TextStyle(
                        color: AppColors.textMutedDark,
                        fontSize: 10.sp,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Price + change
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price > 0 ? formatPrice(price) : '--',
                  style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                SizedBox(height: 2.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: changeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    '$changePrefix${change.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: changeColor,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            // Star / watchlist toggle
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(watchlistProvider.notifier).toggle(market.symbol);
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                child: Icon(
                  isWatched ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isWatched
                      ? const Color(0xFFF5C518)
                      : AppColors.textMutedDark,
                  size: 20.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SymbolAvatar extends StatelessWidget {
  final String symbol;
  final Color? positionColor;
  const _SymbolAvatar({required this.symbol, this.positionColor});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 36.w,
          height: 36.w,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  positionColor?.withOpacity(0.5) ??
                  AppColors.primary.withOpacity(0.3),
              width: positionColor != null ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            symbol.length >= 3 ? symbol.substring(0, 3) : symbol,
            style: TextStyle(
              color: AppColors.primaryLight,
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        if (positionColor != null)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: 9.w,
              height: 9.w,
              decoration: BoxDecoration(
                color: positionColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.backgroundDark, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}
