import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/providers/auth/client_auth_provider.dart';
import '../../../../core/models/app_notification.dart';
import '../../../../core/providers/solana/wallet_name_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/notifications/remote_notification_service.dart';
import '../../../../core/providers/notifications/notifications_provider.dart';
import '../../../../features/notifications/presentation/pages/notifications_page.dart';
import '../../../../shared/widgets/dream_display.dart';
import '../../../intelligence/presentation/pages/intelligence_tab_page.dart';
import '../../../markets/presentation/pages/markets_page.dart';
import '../../../markets/providers/market_search_provider.dart';
import '../../../markets/providers/market_watchlist_filter_provider.dart';
import '../../../trade/presentation/pages/trade_page.dart';
import '../../../trade/providers/trade_provider.dart';
import '../../../positions/presentation/pages/positions_page.dart';
import '../../../account/presentation/pages/account_page.dart';
import '../../../account/presentation/pages/history_page.dart';
import '../../providers/bottom_nav_providers.dart';
import 'bottom_nav.dart';
import 'notification_runtime_listener.dart';
import 'shell_banners.dart';
import 'wallet_deposit_listener.dart';

/// Main application shell — 4-tab trading terminal.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final Set<int> _loadedTabs = {0};

  StreamSubscription<String>? _notifTapSub;
  StreamSubscription<AppNotification>? _notifFeedSub;
  StreamSubscription<NotificationTapPayload>? _remoteNotifTapSub;

  void _openTradeFromSymbol(String? symbol) {
    if (symbol == null || symbol.isEmpty) return;
    ref.read(tradeProvider.notifier).selectSymbol(symbol);
    ref.read(bottomNavIndexProvider.notifier).setIndex(1);
  }

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
    _notifTapSub = notifService.alertTapSymbol.listen(_openTradeFromSymbol);
    final remoteNotifService = ref.read(remoteNotificationServiceProvider);
    _remoteNotifTapSub = remoteNotifService.tapPayloads.listen((payload) {
      _openTradeFromSymbol(payload.symbol);
    });
    // Forward all shown notifications into the in-app feed store.
    _notifFeedSub = notifService.notificationFeed.listen((appNotif) {
      ref.read(notificationsProvider.notifier).add(appNotif);
    });
    // Handle the case where the user is already authenticated on load.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pendingTap = remoteNotifService.consumePendingTap();
      if (pendingTap != null) {
        _openTradeFromSymbol(pendingTap.symbol);
      }

      final auth = ref.read(clientAuthProvider);
      if (auth.isAuthenticated) {
        ref.read(notificationsProvider.notifier).onFirstSignIn();
      }
    });
  }

  @override
  void dispose() {
    _notifTapSub?.cancel();
    _notifFeedSub?.cancel();
    _remoteNotifTapSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(bottomNavIndexProvider);
    _loadedTabs.add(currentIndex);

    // Listen for first-sign-in transitions to send welcome notifications.
    ref.listen<AuthStateData>(clientAuthProvider, (prev, next) {
      if (next.isAuthenticated && (prev == null || !prev.isAuthenticated)) {
        ref.read(notificationsProvider.notifier).onFirstSignIn();
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const NotificationRuntimeListener(),
          const WalletDepositListener(),
          Column(
            children: [
              const WsStatusBanner(),
              _ShellTopBar(currentIndex: currentIndex),
              // Lazy IndexedStack: only mount tabs after the user visits them.
              // This avoids hammering Phoenix/Helius on app start.
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleShellScrollNotification,
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
                      _loadedTabs.contains(4)
                          ? const IntelligenceTabPage()
                          : const SizedBox.shrink(),
                    ],
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

  String _greetingName(AuthStateData auth, {String? resolvedDomain}) {
    // 1. Display name (Google/Apple OAuth typically provides full name)
    final dn = auth.session?.user.displayName;
    if (dn != null && dn.trim().isNotEmpty) {
      return dn.trim().split(' ').first;
    }
    // 2. SNS domain name (.skr, .sol, etc.)
    if (resolvedDomain != null) return resolvedDomain;
    // 3. Email → part before @, capitalised
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
    // 4. Wallet address → truncated
    final wallet = auth.walletAddress;
    if (wallet != null && wallet.length >= 8) {
      return '${wallet.substring(0, 4)}…${wallet.substring(wallet.length - 4)}';
    }
    return 'there';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentIndex == 3) {
      return const SizedBox.shrink();
    }
    final auth = ref.watch(clientAuthProvider);
    final user = auth.session?.user;
    final isAccount = widget.currentIndex == 3;
    final isMarkets = widget.currentIndex == 0;
    final watchlistOnly = ref.watch(marketWatchlistOnlyProvider);
    final avatarSeed = user?.walletAddress ?? user?.id ?? user?.email;

    // Resolve SNS domain name for wallet users
    final walletAddress = auth.walletAddress;
    final resolvedDomain = walletAddress != null
        ? ref.watch(walletNameProvider(walletAddress)).asData?.value
        : null;

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
                          text: _greetingName(
                            auth,
                            resolvedDomain: resolvedDomain,
                          ),
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
                _HistoryIcon(walletAddress: walletAddress),
                _BellIcon(),
              ],
            ),
            if (isMarkets) ...[
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
                                              marketSearchQueryProvider
                                                  .notifier,
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
                    onTap: () {
                      ref.read(marketWatchlistOnlyProvider.notifier).toggle();
                    },
                    child: Icon(
                      watchlistOnly
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 20.sp,
                      color: watchlistOnly
                          ? AppColors.warningLight
                          : AppColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bell icon with unread badge — opens NotificationsPage
// ---------------------------------------------------------------------------

class _BellIcon extends ConsumerWidget {
  const _BellIcon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    final badgeLabel = unread > 99 ? '99+' : '$unread';
    final isSingleDigitBadge = badgeLabel.length == 1;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NotificationsPage()),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.only(left: 8.w),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              PhosphorIcons.bell(PhosphorIconsStyle.bold),
              color: AppColors.textSecondaryDark,
              size: 22.sp,
            ),
            if (unread > 0)
              Positioned(
                top: -3.h,
                right: -5.w,
                child: Container(
                  constraints: BoxConstraints(
                    minWidth: isSingleDigitBadge ? 16.r : 18.w,
                    minHeight: 16.r,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isSingleDigitBadge ? 0 : 4.w,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(999.r),
                    border: Border.all(
                      color: AppColors.backgroundDark,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryIcon extends StatelessWidget {
  final String? walletAddress;

  const _HistoryIcon({required this.walletAddress});

  @override
  Widget build(BuildContext context) {
    if (walletAddress == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => HistoryPage(walletAddress: walletAddress!),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.only(left: 8.w),
        child: Icon(
          PhosphorIcons.clockCounterClockwise(PhosphorIconsStyle.bold),
          color: AppColors.textSecondaryDark,
          size: 22.sp,
        ),
      ),
    );
  }
}
