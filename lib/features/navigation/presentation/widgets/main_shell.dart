import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/notification_service.dart';
import '../../../markets/presentation/pages/markets_page.dart';
import '../../../trade/presentation/pages/trade_page.dart';
import '../../../trade/providers/trade_provider.dart';
import '../../../positions/presentation/pages/positions_page.dart';
import '../../../account/presentation/pages/account_page.dart';
import '../../providers/bottom_nav_providers.dart';
import '../../../../core/providers/phoenix/phoenix_auth_provider.dart';
import 'bottom_nav.dart';
import 'shell_banners.dart';

/// Main application shell — 4-tab trading terminal.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  static const List<Widget> _pages = [
    MarketsPage(), // 0 — market list with live prices
    TradePage(), // 1 — order entry
    PositionsPage(), // 2 — open positions + orders
    AccountPage(), // 3 — equity summary + wallet
  ];

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
    final phoenixAuth = ref.watch(phoenixAuthProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          if (phoenixAuth.needsReauth) const ReauthBanner(),
          const WsStatusBanner(),
          ActivationBanner(currentIndex: currentIndex),
          Expanded(
            child: IndexedStack(index: currentIndex, children: _pages),
          ),
        ],
      ),
      bottomNavigationBar: ShellBottomNav(currentIndex: currentIndex),
    );
  }
}
