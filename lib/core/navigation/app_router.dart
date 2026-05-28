import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_constants.dart';
import '../services/logger_service.dart';
import '../services/phoenix/phoenix_trader_service.dart';
import '../../features/auth/presentation/pages/enhanced_login_page.dart';
import '../../features/auth/presentation/pages/onboarding_page.dart';
import '../../features/account/presentation/pages/activate_page.dart';
import '../../features/navigation/presentation/widgets/main_shell.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/trade/presentation/pages/market_trade_page.dart';
import '../../features/trade/providers/trade_state.dart';
import '../providers/auth/client_auth_provider.dart';
import '../../shared/services/storage_service.dart';

/// Router provider for the app
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      // Splash Route (decides first screen)
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const _SplashPage(),
      ),

      // Onboarding Route
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),

      // // Authentication Routes
      // GoRoute(
      //   path: AppRoutes.login,
      //   name: 'login',
      //   builder: (context, state) => const LoginPage(),
      // ),

      // Enhanced Login Route
      GoRoute(
        path: '/enhanced-login',
        name: 'enhanced-login',
        builder: (context, state) => const EnhancedLoginPage(),
      ),

      // Home Route -> Dashboard Shell with 4 tabs
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const MainShell(),
      ),

      // Full-screen market detail/trade route (outside shell chrome)
      GoRoute(
        path: '/market/:symbol',
        name: 'market-detail',
        builder: (context, state) => _buildMarketTradePage(state),
      ),

      // Shareable canonical trade route for app links and social shares.
      GoRoute(
        path: '/trade/:symbol',
        name: 'trade-share',
        builder: (context, state) => _buildMarketTradePage(state),
      ),

      // Activation gate — shown when Phoenix account not yet registered
      GoRoute(
        path: '/activate',
        name: 'activate',
        builder: (context, state) => const ActivatePage(),
      ),

      // Settings Route
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});

MarketTradePage _buildMarketTradePage(GoRouterState state) {
  final rawSide = state.uri.queryParameters['side']?.toLowerCase();
  final initialSide = switch (rawSide) {
    'buy' || 'long' => OrderSide.buy,
    'sell' || 'short' => OrderSide.sell,
    _ => null,
  };

  final rawLeverage = state.uri.queryParameters['leverage'];
  final initialLeverage = rawLeverage != null
      ? double.tryParse(rawLeverage)?.clamp(1.0, 20.0)
      : null;

  return MarketTradePage(
    symbol: state.pathParameters['symbol'] ?? '',
    initialSide: initialSide,
    initialLeverage: initialLeverage,
  );
}

// Minimal Splash Page that routes based on first-launch and auth status
class _SplashPage extends ConsumerStatefulWidget {
  const _SplashPage();

  @override
  ConsumerState<_SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<_SplashPage> {
  final _logger = LoggerService();

  @override
  void initState() {
    super.initState();
    // Schedule navigation after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndNavigate();
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    // First launch? Go to onboarding immediately
    if (StorageService.isFirstLaunch) {
      if (!mounted) return;
      _logger.info('[Router] First launch detected, going to onboarding');
      context.go(AppRoutes.onboarding);
      return;
    }

    // Wait for clientAuthProvider to initialize (Privy SDK ready)
    final authState = ref.read(clientAuthProvider);

    // If not initialized yet, wait for it
    if (!authState.isInitialized) {
      _logger.info('[Router] Waiting for auth initialization...');

      // Wait up to 3 seconds for initialization
      int attempts = 0;
      while (attempts < 30 && !ref.read(clientAuthProvider).isInitialized) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      if (!ref.read(clientAuthProvider).isInitialized) {
        _logger.warning(
          '[Router] Auth initialization timeout — proceeding anyway',
        );
      }
    }

    // Read final auth state after initialization
    final finalAuthState = ref.read(clientAuthProvider);

    _logger.info('[Router] Auth state: ${finalAuthState.state}');
    _logger.info('[Router] Session exists: ${finalAuthState.session != null}');
    _logger.info('[Router] Initialized: ${finalAuthState.isInitialized}');

    if (!mounted) return;

    if (finalAuthState.isAuthenticated && finalAuthState.session != null) {
      _logger.info(
        '[Router] User authenticated: ${finalAuthState.session!.user.email}',
      );

      final walletAddress = finalAuthState.walletAddress;
      if (walletAddress != null) {
        _logger.info('[Router] Checking Phoenix trader registration...');
        try {
          final traderState = await ref
              .read(phoenixTraderServiceProvider)
              .fetchTraderState(walletAddress);

          if (!mounted) return;

          if (!traderState.isRegistered) {
            _logger.info('[Router] Trader not activated, going to activate');
            context.go('/activate');
            return;
          }
        } catch (e) {
          _logger.warning(
            '[Router] Trader registration check failed; defaulting to home: $e',
          );
        }
      }

      _logger.info('[Router] Navigating to home');
      context.go(AppRoutes.home);
    } else {
      _logger.info('[Router] User not authenticated, going to login');
      context.go('/enhanced-login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// Placeholder pages - will be implemented in later phases
