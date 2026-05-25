import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/providers/auth/client_auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../shared/widgets/dream_display.dart';
import '../../../markets/presentation/pages/markets_page.dart';
import '../../../markets/providers/market_search_provider.dart';
import '../../../markets/providers/market_watchlist_filter_provider.dart';
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

  bool _handleShellScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;

    final navVisibility = ref.read(bottomNavVisibilityProvider.notifier);

    if (notification is UserScrollNotification) {
      switch (notification.direction) {
        case ScrollDirection.forward:
          navVisibility.show();
        case ScrollDirection.reverse:
          navVisibility.hide();
        case ScrollDirection.idle:
          break;
      }
      return false;
    }

    if (notification is OverscrollNotification) {
      if (notification.overscroll < -6) {
        navVisibility.show();
      } else if (notification.overscroll > 6) {
        navVisibility.hide();
      }
      return false;
    }

    if (notification is ScrollEndNotification) {
      final metrics = notification.metrics;
      if (metrics.pixels <= metrics.minScrollExtent + 4) {
        navVisibility.show();
      }
    }

    return false;
  }

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

    void handleHorizontalSwipe(DragEndDetails details) {
      final velocity = details.primaryVelocity ?? 0;
      // Right swipe: Markets -> Positions
      if (velocity > 320 && currentIndex == 0) {
        ref.read(bottomNavIndexProvider.notifier).setIndex(2);
      }
      // Left swipe: Positions -> Markets
      if (velocity < -320 && currentIndex == 2) {
        ref.read(bottomNavIndexProvider.notifier).setIndex(0);
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Column(
            children: [
              const WsStatusBanner(),
              _ShellTopBar(currentIndex: currentIndex),
              // Lazy IndexedStack: only mount tabs after the user visits them.
              // This avoids hammering Phoenix/Helius on app start.
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleShellScrollNotification,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: handleHorizontalSwipe,
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
                ),
              ),
            ],
          ),
          if (currentIndex != 3)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ShellBottomNav(currentIndex: currentIndex),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shell-level top bar — greeting + search + profile avatar
// ---------------------------------------------------------------------------

class _ShellTopBar extends ConsumerStatefulWidget {
  final int currentIndex;
  const _ShellTopBar({required this.currentIndex});

  @override
  ConsumerState<_ShellTopBar> createState() => _ShellTopBarState();
}

class _ShellTopBarState extends ConsumerState<_ShellTopBar> {
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _searchFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!mounted) return;
      setState(() => _searchFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _greetingName(AuthStateData auth) {
    // 1. Display name (Google/Apple OAuth typically provides full name)
    final dn = auth.session?.user.displayName;
    if (dn != null && dn.trim().isNotEmpty) {
      return dn.trim().split(' ').first;
    }
    // 2. Email → part before @, capitalised
    final email = auth.userEmail ?? '';
    if (email.contains('@')) {
      final local = email.split('@').first;
      final part = local
          .replaceAll(RegExp(r'[._+\-]'), ' ')
          .trim()
          .split(' ')
          .first;
      if (part.isNotEmpty) {
        return part[0].toUpperCase() + part.substring(1).toLowerCase();
      }
    }
    // 3. Wallet address → truncated
    final wallet = auth.walletAddress;
    if (wallet != null && wallet.length >= 8) {
      return '${wallet.substring(0, 4)}…${wallet.substring(wallet.length - 4)}';
    }
    return 'there';
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(clientAuthProvider);
    final user = auth.session?.user;
    final isAccount = widget.currentIndex == 3;
    final isMarkets = widget.currentIndex == 0;
    final watchlistOnly = ref.watch(marketWatchlistOnlyProvider);
    final avatarSeed = user?.walletAddress ?? user?.id ?? user?.email;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 32.h, 16.w, 2.h),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () =>
                      ref.read(bottomNavIndexProvider.notifier).setIndex(3),
                  behavior: HitTestBehavior.opaque,
                  child: avatarSeed != null
                      ? DreamAvatar(
                          imageUrl: user?.photoUrl,
                          seed: avatarSeed,
                          size: 45.r,
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
                          size: 26.sp,
                        ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Hi, ',
                          style: TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        TextSpan(
                          text: _greetingName(auth),
                          style: TextStyle(
                            color: AppColors.textPrimaryDark,
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (widget.currentIndex != 3) ...[  
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 36.h,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(18.r),
                      border: Border.all(
                        color: _searchFocused
                            ? AppColors.primary
                            : AppColors.borderDark,
                        width: _searchFocused ? 1.2 : 1,
                      ),
                    ),
                    child: TextField(
                      controller: _textCtrl,
                      focusNode: _focusNode,
                      style: TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 14.sp,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search markets…',
                        hintStyle: TextStyle(
                          color: AppColors.textMutedDark,
                          fontSize: 14.sp,
                        ),
                        prefixIcon: Icon(
                          PhosphorIcons.magnifyingGlass(),
                          size: 17.sp,
                          color: AppColors.textMutedDark,
                        ),
                        suffixIcon: _textCtrl.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _textCtrl.clear();
                                  ref
                                          .read(
                                            marketSearchQueryProvider.notifier,
                                          )
                                          .state =
                                      '';
                                  setState(() {});
                                },
                                child: Icon(
                                  PhosphorIcons.xCircle(),
                                  color: AppColors.textMutedDark,
                                  size: 16.sp,
                                ),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.only(top: 9.h),
                        isDense: true,
                      ),
                      onChanged: (v) {
                        ref.read(marketSearchQueryProvider.notifier).state = v
                            .trim();
                        setState(() {});
                      },
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: isMarkets
                      ? () {
                          ref.read(marketWatchlistOnlyProvider.notifier).state =
                              !watchlistOnly;
                        }
                      : null,
                  child: Icon(
                    watchlistOnly
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 20.sp,
                    color: watchlistOnly
                        ? const Color(0xFFF5C518)
                        : AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
            ], // end if (currentIndex != 3)
          ],
        ),
      ),
    );
  }
}
