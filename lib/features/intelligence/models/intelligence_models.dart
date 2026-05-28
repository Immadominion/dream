// Intelligence feature data models

// ---------------------------------------------------------------------------
// Copy trading models
// ---------------------------------------------------------------------------

class LeaderProfile {
  final String address;
  final String? label;
  final String? twitter;
  final double pnl7d;
  final bool hasPnlHistory;
  final double winRate;
  final int totalTrades;
  final double maxDrawdown;
  final double collateral;
  final double equity;
  final double openNotional;
  final DateTime? lastTradeAt;
  final List<LeaderPosition> openPositions;
  final bool isRegistered;
  final bool isLoading;

  const LeaderProfile({
    required this.address,
    this.label,
    this.twitter,
    this.pnl7d = 0,
    this.hasPnlHistory = false,
    this.winRate = 0,
    this.totalTrades = 0,
    this.maxDrawdown = 0,
    this.collateral = 0,
    this.equity = 0,
    this.openNotional = 0,
    this.lastTradeAt,
    this.openPositions = const [],
    this.isRegistered = false,
    this.isLoading = false,
  });

  String get displayLabel => label ?? _shortAddress(address);
  bool get hasTradeStats => totalTrades > 0;
  bool get hasOpenPositions => openPositions.isNotEmpty;

  static String _shortAddress(String addr) =>
      '${addr.substring(0, 4)}…${addr.substring(addr.length - 4)}';

  LeaderProfile copyWith({
    double? pnl7d,
    bool? hasPnlHistory,
    double? winRate,
    int? totalTrades,
    double? maxDrawdown,
    double? collateral,
    double? equity,
    double? openNotional,
    DateTime? lastTradeAt,
    List<LeaderPosition>? openPositions,
    bool? isRegistered,
    bool? isLoading,
  }) => LeaderProfile(
    address: address,
    label: label,
    twitter: twitter,
    pnl7d: pnl7d ?? this.pnl7d,
    hasPnlHistory: hasPnlHistory ?? this.hasPnlHistory,
    winRate: winRate ?? this.winRate,
    totalTrades: totalTrades ?? this.totalTrades,
    maxDrawdown: maxDrawdown ?? this.maxDrawdown,
    collateral: collateral ?? this.collateral,
    equity: equity ?? this.equity,
    openNotional: openNotional ?? this.openNotional,
    lastTradeAt: lastTradeAt ?? this.lastTradeAt,
    openPositions: openPositions ?? this.openPositions,
    isRegistered: isRegistered ?? this.isRegistered,
    isLoading: isLoading ?? this.isLoading,
  );
}

class LeaderPosition {
  final String market;
  final String side; // 'long' | 'short'
  final double size;
  final double entryPrice;
  final double unrealizedPnl;

  const LeaderPosition({
    required this.market,
    required this.side,
    required this.size,
    required this.entryPrice,
    this.unrealizedPnl = 0,
  });

  factory LeaderPosition.fromJson(Map<String, dynamic> j) {
    final rawSize = _toDouble(j['positionSize'] ?? j['base_asset_amount']);
    final explicitSide = (j['side'] as String?)?.toLowerCase();
    final side = explicitSide ?? (rawSize < 0 ? 'short' : 'long');

    return LeaderPosition(
      market: j['symbol'] as String? ?? '',
      side: side,
      size: rawSize.abs(),
      entryPrice: _toDouble(j['entryPrice'] ?? j['entry_price']),
      unrealizedPnl: _toDouble(j['unrealizedPnl'] ?? j['unrealized_pnl']),
    );
  }
}

class CopySettings {
  final double copyUSDC;
  final double maxSlippage; // e.g. 0.005 = 0.5%
  final double stopLossRatio; // e.g. 0.20 = 20%

  const CopySettings({
    this.copyUSDC = 50.0,
    this.maxSlippage = 0.005,
    this.stopLossRatio = 0.20,
  });

  Map<String, dynamic> toJson() => {
    'copyUSDC': copyUSDC,
    'maxSlippage': maxSlippage,
    'stopLossRatio': stopLossRatio,
  };

  factory CopySettings.fromJson(Map<String, dynamic> j) => CopySettings(
    copyUSDC: (j['copyUSDC'] as num?)?.toDouble() ?? 50.0,
    maxSlippage: (j['maxSlippage'] as num?)?.toDouble() ?? 0.005,
    stopLossRatio: (j['stopLossRatio'] as num?)?.toDouble() ?? 0.20,
  );
}

class FollowedLeader {
  final LeaderProfile leader;
  final CopySettings settings;
  final double gainSinceFollow;
  final bool isPaused;
  final DateTime followedAt;

  // Snapshot of positions at last poll (to detect changes)
  final List<LeaderPosition> lastKnownPositions;

  const FollowedLeader({
    required this.leader,
    required this.settings,
    this.gainSinceFollow = 0,
    this.isPaused = false,
    required this.followedAt,
    this.lastKnownPositions = const [],
  });

  FollowedLeader copyWith({
    LeaderProfile? leader,
    CopySettings? settings,
    double? gainSinceFollow,
    bool? isPaused,
    List<LeaderPosition>? lastKnownPositions,
  }) => FollowedLeader(
    leader: leader ?? this.leader,
    settings: settings ?? this.settings,
    gainSinceFollow: gainSinceFollow ?? this.gainSinceFollow,
    isPaused: isPaused ?? this.isPaused,
    followedAt: followedAt,
    lastKnownPositions: lastKnownPositions ?? this.lastKnownPositions,
  );

  Map<String, dynamic> toJson() => {
    'address': leader.address,
    'label': leader.label,
    'twitter': leader.twitter,
    'settings': settings.toJson(),
    'gainSinceFollow': gainSinceFollow,
    'isPaused': isPaused,
    'followedAt': followedAt.toIso8601String(),
  };

  factory FollowedLeader.fromJson(
    Map<String, dynamic> j,
    LeaderProfile profile,
  ) => FollowedLeader(
    leader: profile,
    settings: CopySettings.fromJson(
      j['settings'] as Map<String, dynamic>? ?? {},
    ),
    gainSinceFollow: (j['gainSinceFollow'] as num?)?.toDouble() ?? 0,
    isPaused: j['isPaused'] as bool? ?? false,
    followedAt:
        DateTime.tryParse(j['followedAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class CopyTradingState {
  final List<LeaderProfile> discover;
  final List<FollowedLeader> following;
  final bool isPolling;
  final bool isLoadingDiscover;
  final bool isAddingLeader;
  final String? error;

  const CopyTradingState({
    this.discover = const [],
    this.following = const [],
    this.isPolling = false,
    this.isLoadingDiscover = false,
    this.isAddingLeader = false,
    this.error,
  });

  CopyTradingState copyWith({
    List<LeaderProfile>? discover,
    List<FollowedLeader>? following,
    bool? isPolling,
    bool? isLoadingDiscover,
    bool? isAddingLeader,
    String? error,
    bool clearError = false,
  }) => CopyTradingState(
    discover: discover ?? this.discover,
    following: following ?? this.following,
    isPolling: isPolling ?? this.isPolling,
    isLoadingDiscover: isLoadingDiscover ?? this.isLoadingDiscover,
    isAddingLeader: isAddingLeader ?? this.isAddingLeader,
    error: clearError ? null : (error ?? this.error),
  );
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

// ---------------------------------------------------------------------------
// AI trading models
// ---------------------------------------------------------------------------

enum RiskMode { conservative, balanced, aggressive }

enum BotAction { buy, sell, hold }

class AIBotConfig {
  final String market;
  final double maxSizeUSDC;
  final double maxLeverage;
  final RiskMode riskMode;
  final double stopLossPercentage;

  const AIBotConfig({
    this.market = 'blue_chips',
    this.maxSizeUSDC = 50.0,
    this.maxLeverage = 3.0,
    this.riskMode = RiskMode.balanced,
    this.stopLossPercentage = 5.0,
  });

  AIBotConfig copyWith({
    String? market,
    double? maxSizeUSDC,
    double? maxLeverage,
    RiskMode? riskMode,
    double? stopLossPercentage,
  }) => AIBotConfig(
    market: market ?? this.market,
    maxSizeUSDC: maxSizeUSDC ?? this.maxSizeUSDC,
    maxLeverage: maxLeverage ?? this.maxLeverage,
    riskMode: riskMode ?? this.riskMode,
    stopLossPercentage: stopLossPercentage ?? this.stopLossPercentage,
  );
}

class BotLogEntry {
  final DateTime timestamp;
  final BotAction action;
  final String reason;
  final double? executedSize;
  final String? txSignature;

  const BotLogEntry({
    required this.timestamp,
    required this.action,
    required this.reason,
    this.executedSize,
    this.txSignature,
  });
}

class AITradingState {
  final bool isRunning;
  final AIBotConfig config;
  final List<BotLogEntry> log;
  final double totalPnl;
  final int aiCredits;
  final bool isLoadingCredits;
  final bool isBuying; // buying more credits
  final String? error;

  const AITradingState({
    this.isRunning = false,
    this.config = const AIBotConfig(),
    this.log = const [],
    this.totalPnl = 0,
    this.aiCredits = 0,
    this.isLoadingCredits = false,
    this.isBuying = false,
    this.error,
  });

  AITradingState copyWith({
    bool? isRunning,
    AIBotConfig? config,
    List<BotLogEntry>? log,
    double? totalPnl,
    int? aiCredits,
    bool? isLoadingCredits,
    bool? isBuying,
    String? error,
    bool clearError = false,
  }) => AITradingState(
    isRunning: isRunning ?? this.isRunning,
    config: config ?? this.config,
    log: log ?? this.log,
    totalPnl: totalPnl ?? this.totalPnl,
    aiCredits: aiCredits ?? this.aiCredits,
    isLoadingCredits: isLoadingCredits ?? this.isLoadingCredits,
    isBuying: isBuying ?? this.isBuying,
    error: clearError ? null : (error ?? this.error),
  );
}

// ---------------------------------------------------------------------------
// Credit purchase tiers
// ---------------------------------------------------------------------------

class CreditTier {
  final int credits;
  final double solPrice;
  final String label;

  const CreditTier({
    required this.credits,
    required this.solPrice,
    required this.label,
  });

  static const List<CreditTier> tiers = [
    CreditTier(credits: 10, solPrice: 0.02, label: 'Starter'),
    CreditTier(credits: 50, solPrice: 0.08, label: 'Trader'),
    CreditTier(credits: 200, solPrice: 0.25, label: 'Pro'),
  ];
}
