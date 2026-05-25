import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/models/phoenix/phoenix_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../markets/providers/markets_provider.dart';
import '../../providers/trade_provider.dart';

// ---------------------------------------------------------------------------
// Bybit-style trade header.
//   Row 1 — back arrow · "Trade" title · fullscreen icon
//   Row 2 — BTC/USDC ▼            [candles | book pill toggle]
//            +0.41%
// ---------------------------------------------------------------------------

class TradeMarketHeader extends ConsumerWidget {
  final TradeState tradeState;
  final MarketsState marketsState;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final bool chartVisible;
  final ValueChanged<bool>? onChartToggle;
  final VoidCallback? onFullscreen;

  const TradeMarketHeader({
    super.key,
    required this.tradeState,
    required this.marketsState,
    this.showBackButton = false,
    this.onBackPressed,
    this.chartVisible = false,
    this.onChartToggle,
    this.onFullscreen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final change = marketsState.changeFor(tradeState.symbol);
    final changeColor = change >= 0 ? AppColors.bullish : AppColors.bearish;

    return Container(
      color: AppColors.backgroundDark,
      child: Column(
        children: [
          SizedBox(
            height: 44.h,
            child: Row(
              children: [
                if (showBackButton)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onBackPressed,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14.w),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.textPrimaryDark,
                        size: 18.sp,
                      ),
                    ),
                  )
                else
                  SizedBox(width: 14.w),
                Expanded(
                  child: Center(
                    child: Text(
                      'Trade',
                      style: TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onFullscreen,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    child: Icon(
                      Icons.open_in_full_rounded,
                      color: AppColors.textPrimaryDark,
                      size: 18.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 12.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showSymbolPicker(context, ref),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _displaySymbol(tradeState.symbol),
                              style: TextStyle(
                                color: AppColors.textPrimaryDark,
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Icon(
                              Icons.arrow_drop_down,
                              color: AppColors.textPrimaryDark,
                              size: 22.sp,
                            ),
                          ],
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          formatPercent(change),
                          style: TextStyle(
                            color: changeColor,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _ChartTogglePill(
                  chartVisible: chartVisible,
                  onChanged: onChartToggle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _displaySymbol(String sym) {
    if (sym.contains('-')) {
      final parts = sym.split('-');
      final base = parts.first;
      final quote = parts.last.replaceAll('PERP', '').toUpperCase();
      return '$base/${quote.isEmpty ? 'USDC' : quote}';
    }
    return sym;
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
        selected: tradeState.symbol,
        onSelect: (symbol) {
          ref.read(tradeProvider.notifier).selectSymbol(symbol);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ChartTogglePill extends StatelessWidget {
  final bool chartVisible;
  final ValueChanged<bool>? onChanged;

  const _ChartTogglePill({required this.chartVisible, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(3.r),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillSide(
            icon: Icons.candlestick_chart_outlined,
            selected: chartVisible,
            onTap: () => onChanged?.call(true),
          ),
          _PillSide(
            icon: Icons.menu_book_outlined,
            selected: !chartVisible,
            onTap: () => onChanged?.call(false),
          ),
        ],
      ),
    );
  }
}

class _PillSide extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _PillSide({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceDark : Colors.transparent,
          borderRadius: BorderRadius.circular(17.r),
        ),
        child: Icon(
          icon,
          size: 17.sp,
          color: selected ? AppColors.textPrimaryDark : AppColors.textMutedDark,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Symbol picker bottom sheet — matches MarketTile design language
// ---------------------------------------------------------------------------

class _SymbolPickerSheet extends ConsumerStatefulWidget {
  final List<PhoenixMarket> markets;
  final String selected;
  final ValueChanged<String> onSelect;

  const _SymbolPickerSheet({
    required this.markets,
    required this.selected,
    required this.onSelect,
  });

  @override
  ConsumerState<_SymbolPickerSheet> createState() => _SymbolPickerSheetState();
}

class _SymbolPickerSheetState extends ConsumerState<_SymbolPickerSheet> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marketsState = ref.watch(marketsProvider);

    final filtered = widget.markets.where((m) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return m.symbol.toLowerCase().contains(q) ||
          m.baseAsset.toLowerCase().contains(q);
    }).toList();

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 0.75.sh),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.only(top: 8.h, bottom: 12.h),
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.borderDark,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            // Search field
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                style: TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 14.sp,
                ),
                decoration: InputDecoration(
                  hintText: 'Search markets',
                  hintStyle: TextStyle(
                    color: AppColors.textMutedDark,
                    fontSize: 14.sp,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.textMutedDark,
                    size: 18.sp,
                  ),
                  filled: true,
                  fillColor: AppColors.cardDark,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 12.h,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            // Market list
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
                        final isSel = m.symbol == widget.selected;
                        final price = marketsState.priceFor(m.symbol);
                        final change = marketsState.changeFor(m.symbol);
                        final changeColor = change >= 0
                            ? AppColors.bullish
                            : AppColors.bearish;

                        return InkWell(
                          onTap: () => widget.onSelect(m.symbol),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Token logo
                                _SheetTokenLogo(
                                  symbol: m.baseAsset,
                                  size: 36.r,
                                ),
                                SizedBox(width: 12.w),
                                // Name + leverage
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            m.baseAsset,
                                            style: TextStyle(
                                              color: AppColors.textPrimaryDark,
                                              fontSize: 14.sp,
                                              fontWeight: isSel
                                                  ? FontWeight.w800
                                                  : FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            ' / USDC',
                                            style: TextStyle(
                                              color: AppColors.textMutedDark,
                                              fontSize: 12.sp,
                                            ),
                                          ),
                                          SizedBox(width: 6.w),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 4.w,
                                              vertical: 1.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.textMutedDark
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(3.r),
                                            ),
                                            child: Text(
                                              '${m.maxLeverage}×',
                                              style: TextStyle(
                                                color: AppColors.textMutedDark,
                                                fontSize: 9.sp,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Price + change pill
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      price > 0 ? formatPrice(price) : '--',
                                      style: TextStyle(
                                        color: AppColors.textPrimaryDark,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 7.w,
                                        vertical: 3.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: changeColor,
                                        borderRadius: BorderRadius.circular(
                                          999.r,
                                        ),
                                      ),
                                      child: Text(
                                        formatPercent(change),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w700,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // Active indicator
                                if (isSel) ...[
                                  SizedBox(width: 10.w),
                                  Icon(
                                    Icons.check_rounded,
                                    color: AppColors.primary,
                                    size: 16.sp,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Token logo for the picker — circle with CoinGecko CDN image + monogram fallback
// ---------------------------------------------------------------------------

class _SheetTokenLogo extends StatelessWidget {
  final String symbol;
  final double size;

  static const Map<String, String> _logos = {
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
    'SOL-PERP':
        'https://coin-images.coingecko.com/coins/images/4128/thumb/solana.png',
  };

  const _SheetTokenLogo({required this.symbol, required this.size});

  @override
  Widget build(BuildContext context) {
    final url = _logos[symbol];
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => _monogram(symbol, size),
                placeholder: (context, url) => _monogram(symbol, size),
              )
            : _monogram(symbol, size),
      ),
    );
  }

  Widget _monogram(String sym, double size) {
    return Container(
      color: AppColors.cardDark,
      alignment: Alignment.center,
      child: Text(
        sym.isNotEmpty ? sym[0] : '?',
        style: TextStyle(
          color: AppColors.textSecondaryDark,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
