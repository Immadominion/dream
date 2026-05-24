import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/models/phoenix/phoenix_models.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

    final isPositive = change >= 0;
    final changeColor = isPositive ? AppColors.bullish : AppColors.bearish;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 4.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.r),
          child: Ink(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _TokenLogo(
                  symbol: market.baseAsset,
                  size: 38.r,
                  borderColor: hasPosition
                      ? posColor.withValues(alpha: 0.42)
                      : Colors.transparent,
                ),
                SizedBox(width: 12.w),
                // Left side: Symbols and Volume
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                            market.baseAsset,
                            style: TextStyle(
                              color: AppColors.textPrimaryDark,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            ' / USDC',
                            style: TextStyle(
                              color: AppColors.textMutedDark,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          if (hasPosition)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: posColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4.r),
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
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        snapshot != null
                            ? '${formatCompact(snapshot.volume24hUsd)} USDC'
                            : '0.00 USDC',
                        style: TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Right side: Price and Change Pill
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          price > 0 ? formatPrice(price) : '--',
                          style: TextStyle(
                            color: AppColors.textPrimaryDark,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        SizedBox(width: 6.w),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref
                                .read(watchlistProvider.notifier)
                                .toggle(market.symbol);
                          },
                          child: Icon(
                            isWatched
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: isWatched
                                ? const Color(0xFFF5C518)
                                : AppColors.textMutedDark,
                            size: 18.sp,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: changeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        formatPercent(change),
                        style: TextStyle(
                          color: changeColor,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
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
// Token logo — loads from CoinGecko CDN, falls back to a styled monogram
// ---------------------------------------------------------------------------

class _TokenLogo extends StatelessWidget {
  final String symbol;
  final double size;
  final Color? borderColor;

  // Exact remote logos for Phoenix's current live market set.
  static const Map<String, String> _logoUrls = {
    'AAVE':
        'https://coin-images.coingecko.com/coins/images/12645/thumb/aave-token-round.png',
    'BNB':
        'https://coin-images.coingecko.com/coins/images/825/thumb/bnb-icon2_2x.png',
    'BTC': 'https://coin-images.coingecko.com/coins/images/1/thumb/bitcoin.png',
    'CHIP':
        'https://coin-images.coingecko.com/coins/images/102171777/thumb/CHIP_Token_Logo_Large.png',
    'COPPER':
        'https://coin-images.coingecko.com/coins/images/67946/thumb/copper_%281%29.png',
    'DOGE':
        'https://coin-images.coingecko.com/coins/images/5/thumb/dogecoin.png',
    'ENA':
        'https://coin-images.coingecko.com/coins/images/36530/thumb/ethena.png',
    'ETH':
        'https://coin-images.coingecko.com/coins/images/279/thumb/ethereum.png',
    'FARTCOIN':
        'https://coin-images.coingecko.com/coins/images/50891/thumb/fart.jpg',
    'GOLD':
        'https://coin-images.coingecko.com/coins/images/102172044/thumb/LOGO.jpeg',
    'HYPE':
        'https://coin-images.coingecko.com/coins/images/50882/thumb/hyperliquid.jpg',
    'JTO': 'https://coin-images.coingecko.com/coins/images/33228/thumb/jto.png',
    'JUP': 'https://coin-images.coingecko.com/coins/images/34188/thumb/jup.png',
    'LIT':
        'https://coin-images.coingecko.com/coins/images/71121/thumb/lighter.png',
    'MEGA':
        'https://coin-images.coingecko.com/coins/images/69995/thumb/9fcb2fa4-b240-46e2-9016-c4f6101a139d.jpeg',
    'MET':
        'https://coin-images.coingecko.com/coins/images/69110/thumb/meteora.png',
    'MON': 'https://coin-images.coingecko.com/coins/images/38927/thumb/mon.png',
    'NEAR':
        'https://coin-images.coingecko.com/coins/images/10365/thumb/near.jpg',
    'PUMP':
        'https://coin-images.coingecko.com/coins/images/67164/thumb/pump.jpg',
    'SILVER':
        'https://coin-images.coingecko.com/coins/images/71267/thumb/4ukvhg7d33t37fy3s25us5lsuogr.',
    'SKR':
        'https://coin-images.coingecko.com/coins/images/70974/thumb/seeker-logo.jpg',
    'SOL':
        'https://coin-images.coingecko.com/coins/images/4128/thumb/solana.png',
    'SUI':
        'https://coin-images.coingecko.com/coins/images/26375/thumb/sui-ocean-square.png',
    'TAO':
        'https://coin-images.coingecko.com/coins/images/28452/thumb/ARUsPeNQ_400x400.jpeg',
    'TON':
        'https://coin-images.coingecko.com/coins/images/17980/thumb/photo_2024-09-10_17.09.00.jpeg',
    'VVV':
        'https://coin-images.coingecko.com/coins/images/54023/thumb/VVV_Token_Transparent.png',
    'WTIOIL':
        'https://coin-images.coingecko.com/coins/images/102172516/thumb/crude_400x400.jpg',
    'XPL':
        'https://coin-images.coingecko.com/coins/images/66489/thumb/Plasma-symbol-green-1.png',
    'XRP':
        'https://coin-images.coingecko.com/coins/images/44/thumb/xrp-symbol-white-128.png',
    'ZEC':
        'https://coin-images.coingecko.com/coins/images/486/thumb/circle-zcash-color.png',
  };

  const _TokenLogo({
    required this.symbol,
    required this.size,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = _logoUrls[symbol.toUpperCase()];
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final targetPx = (size * devicePixelRatio).round();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceDark,
        border: Border.all(
          color: borderColor ?? AppColors.borderDark,
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: imageUrl == null
            ? const SizedBox.shrink()
            : Image(
                image: ResizeImage.resizeIfNeeded(
                  targetPx,
                  targetPx,
                  CachedNetworkImageProvider(imageUrl),
                ),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
      ),
    );
  }
}

