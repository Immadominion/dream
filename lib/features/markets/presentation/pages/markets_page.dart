import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/phoenix/phoenix_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/markets_provider.dart';
import '../../providers/market_search_provider.dart';
import '../../providers/market_watchlist_filter_provider.dart';
import '../../providers/watchlist_provider.dart';
import '../widgets/market_tile.dart';
import '../widgets/markets_header.dart';

class MarketsPage extends ConsumerStatefulWidget {
  const MarketsPage({super.key});

  @override
  ConsumerState<MarketsPage> createState() => _MarketsPageState();
}

class _MarketsPageState extends ConsumerState<MarketsPage> {
  // Multiple filters can be active at once.
  // Each entry: mode → direction (desc = high first, asc = low first).
  // When multiple are active, a composite normalized score is used.
  final Map<MarketSortMode, SortDirection> _filters = {};
  void _onSortTapped(MarketSortMode mode) {
    setState(() {
      final current = _filters[mode] ?? SortDirection.none;
      switch (current) {
        case SortDirection.none:
          _filters[mode] = SortDirection.desc;
        case SortDirection.desc:
          _filters[mode] = SortDirection.asc;
        case SortDirection.asc:
          _filters.remove(mode);
      }
    });
  }

  double _rawValue(MarketSortMode mode, String sym, MarketsState state) =>
      switch (mode) {
        MarketSortMode.change => state.snapshots[sym]?.change24hPercent ?? 0,
        MarketSortMode.volume => state.snapshots[sym]?.volume24hUsd ?? 0,
        MarketSortMode.oi => state.snapshots[sym]?.openInterestUsd ?? 0,
        MarketSortMode.funding =>
          (state.snapshots[sym]?.fundingRate ?? 0).abs(),
      };

  List<PhoenixMarket> _sortMarkets(
    List<PhoenixMarket> markets,
    MarketsState state,
  ) {
    final active = Map.fromEntries(
      _filters.entries.where((e) => e.value != SortDirection.none),
    );
    if (active.isEmpty) return markets;

    if (active.length == 1) {
      // Fast path — simple single-column sort
      final entry = active.entries.first;
      final sorted = List<PhoenixMarket>.from(markets)
        ..sort((a, b) {
          final cmp = _rawValue(
            entry.key,
            a.symbol,
            state,
          ).compareTo(_rawValue(entry.key, b.symbol, state));
          return entry.value == SortDirection.desc ? -cmp : cmp;
        });
      return sorted;
    }

    // Multi-filter: normalize each criterion to [0,1] and sum scores.
    // desc direction → high raw value = high score (good)
    // asc  direction → low  raw value = high score (good)
    final scores = <PhoenixMarket, double>{};
    for (final entry in active.entries) {
      final values = markets
          .map((m) => _rawValue(entry.key, m.symbol, state))
          .toList();
      final minV = values.reduce(min);
      final maxV = values.reduce(max);
      final range = maxV - minV;

      for (int i = 0; i < markets.length; i++) {
        final normalized = range > 0 ? (values[i] - minV) / range : 0.5;
        final score = entry.value == SortDirection.desc
            ? normalized
            : (1.0 - normalized);
        scores[markets[i]] = (scores[markets[i]] ?? 0) + score;
      }
    }

    return List<PhoenixMarket>.from(markets)
      ..sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(marketsProvider);
    final watchlist = ref.watch(watchlistProvider);
    final searchQuery = ref
        .watch(marketSearchQueryProvider)
        .toLowerCase()
        .trim();
    final watchlistOnly = ref.watch(marketWatchlistOnlyProvider);

    var markets = state.markets.where((m) {
      if (watchlistOnly && !watchlist.contains(m.symbol)) return false;
      return true;
    }).toList();

    // Search filtering — rank by relevance, skip sort chips when querying
    if (searchQuery.isNotEmpty) {
      int score(PhoenixMarket m) {
        final symbol = m.symbol.toLowerCase();
        final base = m.baseAsset.toLowerCase();
        if (symbol == searchQuery || base == searchQuery) return 4;
        if (base.startsWith(searchQuery)) return 3;
        if (symbol.startsWith(searchQuery)) return 2;
        if (symbol.contains(searchQuery) || base.contains(searchQuery)) {
          return 1;
        }
        return -1;
      }

      markets = markets.where((m) => score(m) > 0).toList()
        ..sort((a, b) {
          final sc = score(b).compareTo(score(a));
          if (sc != 0) return sc;
          final volA = state.snapshots[a.symbol]?.volume24hUsd ?? 0;
          final volB = state.snapshots[b.symbol]?.volume24hUsd ?? 0;
          return volB.compareTo(volA);
        });
    } else {
      markets = _sortMarkets(markets, state);
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            MarketsHeader(activeFilters: _filters, onSortTapped: _onSortTapped),
            Expanded(
              child: _MarketsBody(
                state: state,
                filteredMarkets: markets,
                watchlistOnly: watchlistOnly,
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
        message = 'No markets available right now';
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
      child: _CurveListView(markets: filteredMarkets),
    );
  }
}

class _CurveListView extends ConsumerStatefulWidget {
  final List<PhoenixMarket> markets;
  const _CurveListView({required this.markets});

  @override
  ConsumerState<_CurveListView> createState() => _CurveListViewState();
}

class _CurveListViewState extends ConsumerState<_CurveListView> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _controller,
      cacheExtent: 320,
      padding: EdgeInsets.fromLTRB(
        0,
        6.h,
        0,
        MediaQuery.paddingOf(context).bottom + 24.h,
      ),
      itemCount: widget.markets.length,
      itemBuilder: (context, index) {
        final market = widget.markets[index];
        final child = MarketTile(
          market: market,
          onTap: () {
            context.push('/market/${market.symbol}');
          },
        );

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // Only scale if attached and has dimensions
            if (!_controller.hasClients ||
                _controller.position.viewportDimension == 0.0) {
              return child;
            }

            final RenderBox? box = context.findRenderObject() as RenderBox?;
            if (box == null) return child;

            try {
              final offset = box.localToGlobal(Offset.zero);
              final itemCenterY = offset.dy + (box.size.height / 2);

              // Find screen center roughly
              final screenHeight = MediaQuery.sizeOf(context).height;
              final centerY = screenHeight / 2;

              final distance = (itemCenterY - centerY).abs();
              final ratio = (distance / (screenHeight / 2)).clamp(0.0, 1.0);

              // Items at edges scale down slightly to 0.88, center items are 1.0
              final scale = 1.0 - (ratio * 0.12);

              return Transform.scale(scale: scale, child: child);
            } catch (e) {
              return child; // Fallback if layout isn't fully ready
            }
          },
        );
      },
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
