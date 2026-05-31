// Intelligence feature data models

// ---------------------------------------------------------------------------
// Copy trading models
// ---------------------------------------------------------------------------

class LeaderProfile {
  final String address;
  final String? label;
  final String? twitter;
  final String? strategy;
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
  final bool isBroadcaster;
  final int copierCount;
  final double lifetimeUsd;
  final bool isLoading;

  const LeaderProfile({
    required this.address,
    this.label,
    this.twitter,
    this.strategy,
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
    this.isBroadcaster = false,
    this.copierCount = 0,
    this.lifetimeUsd = 0,
    this.isLoading = false,
  });

  String get displayLabel => label ?? _shortAddress(address);
  bool get hasTradeStats => totalTrades > 0;
  bool get hasOpenPositions => openPositions.isNotEmpty;

  static String _shortAddress(String addr) =>
      '${addr.substring(0, 4)}…${addr.substring(addr.length - 4)}';

  LeaderProfile copyWith({
    String? label,
    String? twitter,
    String? strategy,
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
    bool? isBroadcaster,
    int? copierCount,
    double? lifetimeUsd,
    bool? isLoading,
  }) => LeaderProfile(
    address: address,
    label: label ?? this.label,
    twitter: twitter ?? this.twitter,
    strategy: strategy ?? this.strategy,
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
    isBroadcaster: isBroadcaster ?? this.isBroadcaster,
    copierCount: copierCount ?? this.copierCount,
    lifetimeUsd: lifetimeUsd ?? this.lifetimeUsd,
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

// ---------------------------------------------------------------------------
// Credit tiers — must match CREDIT_PACKS in dream-ai-worker.ts
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

class CopyTradingState {
  final List<LeaderProfile> discover;
  final List<FollowedLeader> following;
  final LeaderProfile? myBroadcaster;
  final bool isPolling;
  final bool isLoadingDiscover;
  final bool isLoadingBroadcaster;
  final bool isRegisteringBroadcaster;
  final bool isAddingLeader;
  final String? error;

  /// Copy-trade points remaining. One point is spent per mirrored position
  /// open; closing a copied position is always free.
  final int points;
  final bool pointsLoaded;
  final bool isLoadingCredits;
  final bool isBuying;

  const CopyTradingState({
    this.discover = const [],
    this.following = const [],
    this.myBroadcaster,
    this.isPolling = false,
    this.isLoadingDiscover = false,
    this.isLoadingBroadcaster = false,
    this.isRegisteringBroadcaster = false,
    this.isAddingLeader = false,
    this.error,
    this.points = 0,
    this.pointsLoaded = false,
    this.isLoadingCredits = false,
    this.isBuying = false,
  });

  bool get hasPoints => points > 0;

  CopyTradingState copyWith({
    List<LeaderProfile>? discover,
    List<FollowedLeader>? following,
    LeaderProfile? myBroadcaster,
    bool clearMyBroadcaster = false,
    bool? isPolling,
    bool? isLoadingDiscover,
    bool? isLoadingBroadcaster,
    bool? isRegisteringBroadcaster,
    bool? isAddingLeader,
    String? error,
    bool clearError = false,
    int? points,
    bool? pointsLoaded,
    bool? isLoadingCredits,
    bool? isBuying,
  }) => CopyTradingState(
    discover: discover ?? this.discover,
    following: following ?? this.following,
    myBroadcaster: clearMyBroadcaster
        ? null
        : (myBroadcaster ?? this.myBroadcaster),
    isPolling: isPolling ?? this.isPolling,
    isLoadingDiscover: isLoadingDiscover ?? this.isLoadingDiscover,
    isLoadingBroadcaster: isLoadingBroadcaster ?? this.isLoadingBroadcaster,
    isRegisteringBroadcaster:
        isRegisteringBroadcaster ?? this.isRegisteringBroadcaster,
    isAddingLeader: isAddingLeader ?? this.isAddingLeader,
    error: clearError ? null : (error ?? this.error),
    points: points ?? this.points,
    pointsLoaded: pointsLoaded ?? this.pointsLoaded,
    isLoadingCredits: isLoadingCredits ?? this.isLoadingCredits,
    isBuying: isBuying ?? this.isBuying,
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
