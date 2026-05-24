import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/models/phoenix/phoenix_models.dart';
import '../../../../core/providers/auth/client_auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../shared/widgets/dream_display.dart';
import '../../../markets/presentation/pages/markets_page.dart';
import '../../../markets/providers/markets_provider.dart';
import '../../../trade/presentation/pages/trade_page.dart';
import '../../../trade/providers/trade_provider.dart';
import '../../../positions/presentation/pages/positions_page.dart';
import '../../../account/presentation/pages/account_page.dart';
import '../../providers/bottom_nav_providers.dart';
import 'bottom_nav.dart';
import 'shell_banners.dart';

/// Main application shell — 4-tab trading terminal.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final Set<int> _loadedTabs = {0};

  StreamSubscription<String>? _notifTapSub;

  @override
  void initState() {
    super.initState();
    // Listen for notification taps and deep-link to the Trade tab.
    final notifService = ref.read(notificationServiceProvider);
    _notifTapSub = notifService.alertTapSymbol.listen((symbol) {
      ref.read(tradeProvider.notifier).selectSymbol(symbol);
      ref.read(bottomNavIndexProvider.notifier).setIndex(1);
    });
  }

  @override
  void dispose() {
    _notifTapSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(bottomNavIndexProvider);
    _loadedTabs.add(currentIndex);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          const WsStatusBanner(),
          _ShellTopBar(currentIndex: currentIndex),
          // Lazy IndexedStack: only mount tabs after the user visits them.
          // This avoids hammering Phoenix/Helius on app start.
          Expanded(
            child: IndexedStack(
              index: currentIndex,
              children: [
                _loadedTabs.contains(0)
                    ? const MarketsPage()
                    : const SizedBox.shrink(),
                _loadedTabs.contains(1)
                    ? const TradePage()
                    : const SizedBox.shrink(),
                _loadedTabs.contains(2)
                    ? const PositionsPage()
                    : const SizedBox.shrink(),
                _loadedTabs.contains(3)
                    ? const AccountPage()
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: ShellBottomNav(currentIndex: currentIndex),
    );
  }
}

// ---------------------------------------------------------------------------
// Shell-level top bar — search + profile icons, always visible
// ---------------------------------------------------------------------------

class _ShellTopBar extends ConsumerWidget {
  final int currentIndex;
  const _ShellTopBar({required this.currentIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(clientAuthProvider).session?.user;
    final isAccount = currentIndex == 3;
    final avatarSeed = user?.walletAddress ?? user?.id ?? user?.email;

    return SafeArea(
      bottom: false,
      child: Container(
        color: Colors.transparent,
        height: 52.h,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 2.h, 16.w, 6.h),
          child: Row(
            children: [
              const Spacer(),
              _ShellActionButton(
                isActive: false,
                onTap: () async {
                  final marketsState = ref.read(marketsProvider);
                  final selectedSymbol = await showSearch<String?>(
                    context: context,
                    delegate: _MarketSearchDelegate(
                      markets: marketsState.markets,
                      snapshots: marketsState.snapshots,
                    ),
                  );
                  if (!context.mounted || selectedSymbol == null) {
                    return;
                  }
                  ref.read(tradeProvider.notifier).selectSymbol(selectedSymbol);
                  ref.read(bottomNavIndexProvider.notifier).setIndex(1);
                },
                child: Icon(
                  PhosphorIcons.magnifyingGlass(),
                  color: AppColors.textPrimaryDark,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 8.w),
              _ShellActionButton(
                isActive: isAccount,
                onTap: () =>
                    ref.read(bottomNavIndexProvider.notifier).setIndex(3),
                child: avatarSeed != null
                    ? DreamAvatar(
                        imageUrl: user?.photoUrl,
                        seed: avatarSeed,
                        size: 28.r,
                        borderColor: isAccount
                            ? AppColors.primary.withValues(alpha: 0.65)
                            : AppColors.borderDark,
                      )
                    : Icon(
                        PhosphorIcons.userCircle(
                          isAccount
                              ? PhosphorIconsStyle.duotone
                              : PhosphorIconsStyle.regular,
                        ),
                        color: isAccount
                            ? AppColors.primaryLight
                            : AppColors.textSecondaryDark,
                        size: 22.sp,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShellActionButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  final Widget child;

  const _ShellActionButton({
    required this.isActive,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: 44.w,
        height: 44.h,
        padding: EdgeInsets.all(6.r),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.14)
              : AppColors.surfaceDark.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.34)
                : AppColors.borderDark,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              spreadRadius: -10,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _MarketSearchDelegate extends SearchDelegate<String?> {
  final List<PhoenixMarket> markets;
  final Map<String, PhoenixMarketSnapshot> snapshots;

  _MarketSearchDelegate({required this.markets, required this.snapshots});

  @override
  String get searchFieldLabel => 'Search markets';

  @override
  TextStyle? get searchFieldStyle => TextStyle(
    color: AppColors.textPrimaryDark,
    fontSize: 15.sp,
    fontWeight: FontWeight.w600,
  );

  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.backgroundDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: AppColors.textMutedDark,
          fontSize: 15.sp,
          fontWeight: FontWeight.w500,
        ),
        border: InputBorder.none,
      ),
    );
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: Icon(
        PhosphorIcons.arrowLeft(),
        color: AppColors.textPrimaryDark,
        size: 20.sp,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    if (query.isEmpty) {
      return [SizedBox(width: 12.w)];
    }
    return [
      IconButton(
        onPressed: () => query = '',
        icon: Icon(
          PhosphorIcons.xCircle(),
          color: AppColors.textMutedDark,
          size: 18.sp,
        ),
      ),
    ];
  }

  @override
  Widget buildSuggestions(BuildContext context) => _buildBody(context);

  @override
  Widget buildResults(BuildContext context) => _buildBody(context);

  Widget _buildBody(BuildContext context) {
    final results = _rankedMarkets();

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Text(
            'No markets match "$query"',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 14.sp,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
      itemCount: results.length,
      separatorBuilder: (context, index) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        final market = results[index];
        final snapshot = snapshots[market.symbol];
        return _MarketSearchResultTile(
          market: market,
          snapshot: snapshot,
          onTap: () => close(context, market.symbol),
        );
      },
    );
  }

  List<PhoenixMarket> _rankedMarkets() {
    final normalizedQuery = query.trim().toLowerCase();
    final sorted = [...markets];

    int score(PhoenixMarket market) {
      if (normalizedQuery.isEmpty) return 0;
      final symbol = market.symbol.toLowerCase();
      final base = market.baseAsset.toLowerCase();
      if (symbol == normalizedQuery || base == normalizedQuery) return 4;
      if (base.startsWith(normalizedQuery)) return 3;
      if (symbol.startsWith(normalizedQuery)) return 2;
      if (symbol.contains(normalizedQuery) || base.contains(normalizedQuery)) {
        return 1;
      }
      return -1;
    }

    sorted.sort((a, b) {
      final scoreCompare = score(b).compareTo(score(a));
      if (scoreCompare != 0) return scoreCompare;
      final volumeA = snapshots[a.symbol]?.volume24hUsd ?? 0;
      final volumeB = snapshots[b.symbol]?.volume24hUsd ?? 0;
      return volumeB.compareTo(volumeA);
    });

    if (normalizedQuery.isEmpty) {
      return sorted.take(24).toList();
    }

    return sorted.where((market) => score(market) > 0).take(30).toList();
  }
}

class _MarketSearchResultTile extends StatelessWidget {
  final PhoenixMarket market;
  final PhoenixMarketSnapshot? snapshot;
  final VoidCallback onTap;

  const _MarketSearchResultTile({
    required this.market,
    required this.snapshot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final change = snapshot?.change24hPercent ?? 0;
    final changeColor = change >= 0 ? AppColors.bullish : AppColors.bearish;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22.r),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(color: AppColors.borderDark),
          ),
          padding: EdgeInsets.all(14.r),
          child: Row(
            children: [
              DreamAvatar(seed: market.baseAsset, size: 42.r),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      market.baseAsset,
                      style: TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      '${market.quoteAsset} perpetual · ${market.maxLeverage}x max',
                      style: TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    snapshot != null ? formatPrice(snapshot!.markPrice) : '--',
                    style: TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: changeColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999.r),
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
            ],
          ),
        ),
      ),
    );
  }
}
