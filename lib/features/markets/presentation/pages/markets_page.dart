import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/models/phoenix/phoenix_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/markets_provider.dart';
import '../../providers/watchlist_provider.dart';
import '../../../trade/providers/trade_provider.dart';
import '../../../navigation/providers/bottom_nav_providers.dart';
import '../widgets/market_tile.dart';
import '../widgets/markets_header.dart';

class MarketsPage extends ConsumerStatefulWidget {
  const MarketsPage({super.key});

  @override
  ConsumerState<MarketsPage> createState() => _MarketsPageState();
}

class _MarketsPageState extends ConsumerState<MarketsPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  MarketSortMode _sort = MarketSortMode.change;
  bool _sortDesc = true;
  bool _watchlistOnly = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(marketsProvider);
    final watchlist = ref.watch(watchlistProvider);

    var markets = state.markets.where((m) {
      if (_watchlistOnly && !watchlist.contains(m.symbol)) return false;
      if (_query.isEmpty) return true;
      return m.symbol.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    markets.sort((a, b) {
      double sortVal(MarketSortMode s, String sym) => switch (s) {
        MarketSortMode.change => state.snapshots[sym]?.change24hPercent ?? 0,
        MarketSortMode.volume => state.snapshots[sym]?.volume24hUsd ?? 0,
        MarketSortMode.oi => state.snapshots[sym]?.openInterestUsd ?? 0,
        MarketSortMode.funding =>
          (state.snapshots[sym]?.fundingRate ?? 0).abs(),
      };
      final cmp = sortVal(_sort, a.symbol).compareTo(sortVal(_sort, b.symbol));
      return _sortDesc ? -cmp : cmp;
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            MarketsHeader(
              searchCtrl: _searchCtrl,
              sort: _sort,
              sortDesc: _sortDesc,
              watchlistOnly: _watchlistOnly,
              onQueryChanged: (q) => setState(() => _query = q),
              onSortChanged: (s) => setState(() {
                if (_sort == s) {
                  _sortDesc = !_sortDesc;
                } else {
                  _sort = s;
                  _sortDesc = true;
                }
              }),
              onWatchlistOnlyToggled: () =>
                  setState(() => _watchlistOnly = !_watchlistOnly),
              onRefresh: () => ref.read(marketsProvider.notifier).refresh(),
            ),
            Expanded(
              child: _MarketsBody(
                state: state,
                filteredMarkets: markets,
                watchlistOnly: _watchlistOnly,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketsBody extends ConsumerWidget {
  final MarketsState state;
  final List<PhoenixMarket> filteredMarkets;
  final bool watchlistOnly;
  const _MarketsBody({
    required this.state,
    required this.filteredMarkets,
    this.watchlistOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.markets.isEmpty) {
      return const _MarketSkeletonList();
    }

    if (state.error != null && state.markets.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off,
                color: AppColors.textSecondaryDark,
                size: 40.sp,
              ),
              SizedBox(height: 12.h),
              Text(
                state.error!,
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 14.sp,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              TextButton(
                onPressed: () => ref.read(marketsProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (filteredMarkets.isEmpty) {
      String message;
      if (watchlistOnly && state.markets.isNotEmpty) {
        message = 'No starred markets yet.\nTap ⭐ on any market to add it.';
      } else if (state.markets.isEmpty) {
        message = 'No markets available';
      } else {
        message = 'No markets match your search';
      }
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Text(
            message,
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 14.sp,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceDark,
      onRefresh: () => ref.read(marketsProvider.notifier).refresh(),
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: 24.h),
        itemCount: filteredMarkets.length,
        itemBuilder: (context, index) {
          final market = filteredMarkets[index];
          return MarketTile(
            market: market,
            onTap: () {
              ref.read(tradeProvider.notifier).selectSymbol(market.symbol);
              ref.read(bottomNavIndexProvider.notifier).setIndex(1);
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton loading list — shown on first fetch before any markets arrive
// ---------------------------------------------------------------------------

class _MarketSkeletonList extends StatelessWidget {
  const _MarketSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: 24.h),
      itemCount: 12,
      itemBuilder: (context, i) => const _MarketSkeletonTile(),
    );
  }
}

class _MarketSkeletonTile extends StatefulWidget {
  const _MarketSkeletonTile();

  @override
  State<_MarketSkeletonTile> createState() => _MarketSkeletonTileState();
}

class _MarketSkeletonTileState extends State<_MarketSkeletonTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final opacity = 0.3 + _anim.value * 0.35;
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.borderDark, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              // Left: symbol + sub-label
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Slab(width: 56.w, height: 11.h, opacity: opacity),
                  SizedBox(height: 5.h),
                  _Slab(width: 40.w, height: 9.h, opacity: opacity * 0.6),
                ],
              ),
              const Spacer(),
              // Middle: mini chart placeholder
              _Slab(
                width: 60.w,
                height: 24.h,
                opacity: opacity * 0.5,
                radius: 4.r,
              ),
              SizedBox(width: 16.w),
              // Right: price + change
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Slab(width: 72.w, height: 11.h, opacity: opacity),
                  SizedBox(height: 5.h),
                  _Slab(width: 44.w, height: 9.h, opacity: opacity * 0.7),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Slab extends StatelessWidget {
  final double width;
  final double height;
  final double opacity;
  final double? radius;

  const _Slab({
    required this.width,
    required this.height,
    required this.opacity,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.borderDark,
          borderRadius: BorderRadius.circular(radius ?? 3.r),
        ),
      ),
    );
  }
}
