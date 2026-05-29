import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App-wide constants and configuration values
class AppConstants {
  // DEPRECATED: Backend API configuration - NOT USED in production
  // Kept for legacy services that haven't been fully migrated yet
  // Token launches now use Bags API directly (see TokenLaunchService)
  static const String _defaultApiBaseUrl = 'http://localhost:3000/';
  static String get apiBaseUrl =>
      dotenv.get('DREAM_API_BASE_URL', fallback: _defaultApiBaseUrl);

  static Uri apiUri(String path) {
    final sanitizedPath = path.startsWith('/') ? path.substring(1) : path;
    final base = apiBaseUrl.endsWith('/') ? apiBaseUrl : '$apiBaseUrl/';
    return Uri.parse('$base$sanitizedPath');
  }

  // Privy Configuration
  static const String _defaultPrivyHost = 'https://auth.privy.io';
  static String get privyAppId => dotenv.get('PRIVY_APP_ID', fallback: '');
  static String get privyClientId =>
      dotenv.get('PRIVY_CLIENT_ID', fallback: '');
  static String get privyRedirectUri =>
      dotenv.get('PRIVY_REDIRECT_URI', fallback: 'dreamapp://auth-callback');
  static String get privyHost =>
      dotenv.get('PRIVY_LOGIN_HOST', fallback: _defaultPrivyHost);

  static Uri privyLoginUri({
    required String provider,
    String? invitationToken,
    Map<String, String>? additionalParams,
  }) {
    final query = <String, String>{
      'app_id': privyAppId,
      'provider': provider,
      'redirect_uri': privyRedirectUri,
      'embed': 'true',
    };

    if (invitationToken != null && invitationToken.isNotEmpty) {
      query['invitation_token'] = invitationToken;
    }

    if (additionalParams != null) {
      query.addAll(additionalParams);
    }

    return Uri.parse(privyHost).replace(path: '/start', queryParameters: query);
  }

  // App Information
  static const String appName = 'Dream';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Perpetual Futures Trading on Solana';

  // =========================================================================
  // PHOENIX TRADING API
  // =========================================================================

  /// Phoenix REST API — perpetual futures DEX
  static const String phoenixApiBaseUrl = 'https://perp-api.phoenix.trade';

  /// Phoenix WebSocket — live market data, orderbook, trader state
  static const String phoenixWsUrl = 'wss://perp-api.phoenix.trade/v1/ws';

  /// Phoenix Flight builder authority (base58 wallet pubkey).
  /// Register at https://flight.phoenix.trade — this wallet's associated trader
  /// account collects builder fees on every taker fill routed through the app.
  static String get phoenixBuilderAuthority =>
      dotenv.get('PHOENIX_BUILDER_AUTHORITY', fallback: '');

  /// Builder trader account PDA index (default 0 — primary cross account).
  static int get phoenixBuilderPdaIndex =>
      int.tryParse(dotenv.get('PHOENIX_BUILDER_PDA_INDEX', fallback: '0')) ?? 0;

  /// Dream's own Phoenix referral code.
  /// When set (via DREAM_REFERRAL_CODE env var), this code is pre-filled on the
  /// activation page. Future: auto-activate new users under this code.
  static String get dreamReferralCode =>
      dotenv.get('DREAM_REFERRAL_CODE', fallback: '');

  /// Builder trader subaccount index (default 0 — primary subaccount).
  static int get phoenixBuilderSubaccountIndex =>
      int.tryParse(
        dotenv.get('PHOENIX_BUILDER_SUBACCOUNT_INDEX', fallback: '0'),
      ) ??
      0;

  // =========================================================================
  // DREAM AI WORKER
  // =========================================================================

  /// Cloudflare Worker URL — AI proxy that holds HuggingFace + Anthropic keys
  /// as CF Secrets so they never appear in the APK.
  static String get dreamAiWorkerUrl => dotenv.get(
    'DREAM_AI_WORKER_URL',
    fallback: 'https://dream-ai.workers.dev',
  );

  /// Treasury wallet address for AI credit purchases (SOL micropayments).
  /// Set DREAM_TREASURY_ADDRESS in .env — must be a valid Solana base58 pubkey.
  static String get dreamTreasuryAddress =>
      dotenv.get('DREAM_TREASURY_ADDRESS', fallback: '');

  // Legacy Bags API — kept until Bags-dependent features are fully removed
  static const String bagsApiBaseUrl = 'https://public-api-v2.bags.fm/api/v1';
  static const String bagsWebSocketUrl = 'wss://restream.bags.fm';
  static const String solanaRpcUrl = 'https://api.mainnet-beta.solana.com';
  static const String jupiterApiBaseUrl = 'https://api.jup.ag';
  static const String jupiterLiteApiBaseUrl = 'https://lite-api.jup.ag';

  static String get jupiterApiKey =>
      dotenv.get('JUPITER_API_KEY', fallback: '');

  /// Helius RPC URL for Solana RPC calls (getBalance, etc.)
  static String get heliusRpcUrl {
    final apiKey = dotenv.get('HELIUS_API_KEY', fallback: '');
    if (apiKey.isEmpty) return solanaRpcUrl;
    return 'https://mainnet.helius-rpc.com/?api-key=$apiKey';
  }

  /// Helius API URL for REST API calls (transactions, token-metadata, etc.)
  static String get heliusApiUrl => 'https://api.helius.xyz/v0';

  /// Helius API Key for query parameters
  static String get heliusApiKey => dotenv.get('HELIUS_API_KEY', fallback: '');

  // =========================================================================
  // SUPABASE NOTIFICATION BACKEND
  // =========================================================================

  static String get supabaseUrl => dotenv.get('SUPABASE_URL', fallback: '');

  static String get supabaseAnonKey => dotenv.get(
    'SUPABASE_ANON_KEY',
    fallback: dotenv.get('SUPABASE_PUBLISHABLE_KEY', fallback: ''),
  );

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static String get supabaseRegisterDeviceFunction => dotenv.get(
    'SUPABASE_REGISTER_DEVICE_FUNCTION',
    fallback: 'register-device',
  );

  static String get supabaseHeliusWebhookFunction => dotenv.get(
    'SUPABASE_HELIUS_WEBHOOK_FUNCTION',
    fallback: 'helius-webhook',
  );

  static String get supabaseDispatchNotificationsFunction => dotenv.get(
    'SUPABASE_DISPATCH_NOTIFICATIONS_FUNCTION',
    fallback: 'dispatch-notifications',
  );

  static String get supabaseRecordClientEventFunction => dotenv.get(
    'SUPABASE_RECORD_CLIENT_EVENT_FUNCTION',
    fallback: 'record-client-event',
  );

  // Network Configuration
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration webSocketReconnectDelay = Duration(seconds: 5);
  static const int maxRetryAttempts = 3;

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double extraLargePadding = 32.0;

  // Border Radius
  static const double smallBorderRadius = 8.0;
  static const double mediumBorderRadius = 12.0;
  static const double largeBorderRadius = 16.0;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
  static const String themeKey = 'theme_mode';
  static const String walletAddressKey = 'wallet_address';

  // Error Messages
  static const String networkErrorMessage =
      'Network connection error. Please check your internet connection.';
  static const String serverErrorMessage =
      'Server error. Please try again later.';
  static const String unknownErrorMessage = 'An unexpected error occurred.';
  static const String authErrorMessage =
      'Authentication failed. Please login again.';

  // Validation
  static const int minTokenNameLength = 3;
  static const int maxTokenNameLength = 32;
  static const int minTokenSymbolLength = 2;
  static const int maxTokenSymbolLength = 10;
  static const int maxTokenDescriptionLength = 500;

  // Decimal Places
  static const int priceDecimalPlaces = 6;
  static const int percentageDecimalPlaces = 2;
  static const int tokenAmountDecimalPlaces = 2;

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // File Upload
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png', 'webp'];

  // Social Media URL Patterns
  static const String twitterUrlPattern =
      r'^https?://(twitter\.com|x\.com)/[a-zA-Z0-9_]+/?$';
  static const String websiteUrlPattern =
      r'^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/?.*$';

  // Solana Configuration
  static const int lamportsPerSol = 1000000000;
  static const double minSolAmount = 0.001;
  static const double maxSolAmount = 1000.0;
}

/// Route names for navigation
class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/enhanced-login';
  static const String home = '/home';
  static const String search = '/search';
  static const String createToken = '/create-token';
  static const String tokenDetail = '/token/:tokenId';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String wallet = '/wallet';
  static const String portfolio = '/portfolio';
  static const String notifications = '/notifications';
}

/// Asset paths for images, icons, and animations
class AppAssets {
  // Images
  static const String logo = 'assets/images/logo.png';
  static const String defaultTokenImage = 'assets/images/default_token.png';
  static const String placeholder = 'assets/images/placeholder.png';

  // Lottie Animations
  static const String loadingAnimation = 'assets/lottie/loading.json';
  static const String successAnimation = 'assets/animations/success.riv';
  static const String errorAnimation = 'assets/lottie/error.json';
  static const String emptyStateAnimation = 'assets/lottie/empty_state.json';
  static const String walletConnectAnimation =
      'assets/lottie/wallet_connect.json';

  // Icons (custom icons if needed)
  static const String customIconPath = 'assets/icons/';
}

/// Feature flags for enabling/disabling features
class FeatureFlags {
  static const bool enableNotifications = true;
  static const bool enableBiometrics = true;
  static const bool enableDarkMode = true;
  static const bool enableAnalytics = false; // Disable for development
  static const bool enableCrashReporting = false; // Disable for development
  static const bool enableWebSocket = true;
  static const bool enableSocialFeatures = true;
}
