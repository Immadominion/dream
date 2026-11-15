/// Dreams (V2) domain models — mirrors dream-server's `/v1/dreams` DTOs.
///
/// Money arrives as decimal strings and is kept as strings for display; the
/// only arithmetic the app does is the progress ratio, where double precision
/// is fine.
library;

enum DreamCategory {
  medical('Medical', '🩺'),
  education('Education', '🎓'),
  rent('Rent', '🏠'),
  food('Food', '🍲'),
  business('Business', '🛠️'),
  family('Family', '👨‍👩‍👧'),
  emergency('Emergency', '🚨'),
  other('Other', '✨');

  final String label;
  final String emoji;
  const DreamCategory(this.label, this.emoji);

  static DreamCategory parse(String? raw) => DreamCategory.values.firstWhere(
    (c) => c.name == raw,
    orElse: () => DreamCategory.other,
  );
}

enum DreamStatus {
  open,
  funded,
  closed;

  static DreamStatus parse(String? raw) => DreamStatus.values.firstWhere(
    (s) => s.name == raw,
    orElse: () => DreamStatus.open,
  );
}

enum DreamSort { latest, closest, supported }

extension DreamSortApi on DreamSort {
  String get apiValue => switch (this) {
    DreamSort.latest => 'new',
    DreamSort.closest => 'closest',
    DreamSort.supported => 'supported',
  };

  String get label => switch (this) {
    DreamSort.latest => 'New',
    DreamSort.closest => 'Almost there',
    DreamSort.supported => 'Most loved',
  };
}

class DreamCoin {
  final String mint;
  final String pool;
  final String symbol;
  final DateTime? launchedAt;

  const DreamCoin({
    required this.mint,
    required this.pool,
    required this.symbol,
    this.launchedAt,
  });

  factory DreamCoin.fromJson(Map<String, dynamic> j) => DreamCoin(
    mint: j['mint'] as String,
    pool: j['pool'] as String,
    symbol: j['symbol'] as String? ?? '',
    launchedAt: DateTime.tryParse(j['launchedAt'] as String? ?? ''),
  );
}

class Dream {
  final String id;
  final String ownerWallet;
  final String title;
  final String story;
  final DreamCategory category;
  final String goalUsdc;
  final String raisedUsdc;
  final int supporterCount;
  final DreamStatus status;
  final String? xPostUrl;

  /// Verified X handle (set only after the owner proved the post is theirs).
  final String? xHandle;
  final bool hidden;
  final DreamCoin? coin;
  final DateTime createdAt;

  const Dream({
    required this.id,
    required this.ownerWallet,
    required this.title,
    required this.story,
    required this.category,
    required this.goalUsdc,
    required this.raisedUsdc,
    required this.supporterCount,
    required this.status,
    required this.createdAt,
    this.xPostUrl,
    this.xHandle,
    this.hidden = false,
    this.coin,
  });

  double get goal => double.tryParse(goalUsdc) ?? 0;
  double get raised => double.tryParse(raisedUsdc) ?? 0;
  double get progress => goal <= 0 ? 0 : (raised / goal).clamp(0, 1);
  bool get isClosed => status == DreamStatus.closed;

  /// Public share link (handled by app links → `/dreams/:id`).
  String get shareUrl => 'https://trydream.fun/d/$id';

  /// Pre-filled post the owner shares to prove the X account is theirs.
  /// The id goes first: X truncates long posts and link text, and the
  /// server matches on the id.
  String get xVerificationText =>
      'Dream ID $id\n\n$title\n\nHelp make it happen: $shareUrl';

  factory Dream.fromJson(Map<String, dynamic> j) => Dream(
    id: j['id'] as String,
    ownerWallet: j['ownerWallet'] as String,
    title: j['title'] as String,
    story: j['story'] as String,
    category: DreamCategory.parse(j['category'] as String?),
    goalUsdc: j['goalUsdc'] as String? ?? '0',
    raisedUsdc: j['raisedUsdc'] as String? ?? '0',
    supporterCount: (j['supporterCount'] as num?)?.toInt() ?? 0,
    status: DreamStatus.parse(j['status'] as String?),
    xPostUrl: j['xPostUrl'] as String?,
    xHandle: j['xHandle'] as String?,
    hidden: j['hidden'] as bool? ?? false,
    coin: j['coin'] is Map<String, dynamic>
        ? DreamCoin.fromJson(j['coin'] as Map<String, dynamic>)
        : null,
    createdAt:
        DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class CoinStats {
  final bool graduated;
  final double curveProgress;
  final String ownerUnclaimedSol;
  final String ownerLifetimeSol;

  const CoinStats({
    required this.graduated,
    required this.curveProgress,
    required this.ownerUnclaimedSol,
    required this.ownerLifetimeSol,
  });

  bool get hasUnclaimed => (double.tryParse(ownerUnclaimedSol) ?? 0) > 0;

  factory CoinStats.fromJson(Map<String, dynamic> j) => CoinStats(
    graduated: j['graduated'] as bool? ?? false,
    curveProgress: (j['curveProgress'] as num?)?.toDouble() ?? 0,
    ownerUnclaimedSol: j['ownerUnclaimedSol'] as String? ?? '0',
    ownerLifetimeSol: j['ownerLifetimeSol'] as String? ?? '0',
  );
}

class DreamSupporter {
  final String wallet;
  final String amountUsdc;
  final String txSignature;
  final DateTime createdAt;

  const DreamSupporter({
    required this.wallet,
    required this.amountUsdc,
    required this.txSignature,
    required this.createdAt,
  });

  factory DreamSupporter.fromJson(Map<String, dynamic> j) => DreamSupporter(
    wallet: j['wallet'] as String,
    amountUsdc: j['amountUsdc'] as String? ?? '0',
    txSignature: j['txSignature'] as String? ?? '',
    createdAt:
        DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class DreamDetail {
  final Dream dream;
  final CoinStats? coinStats;
  final List<DreamSupporter> supporters;

  const DreamDetail({
    required this.dream,
    required this.supporters,
    this.coinStats,
  });

  factory DreamDetail.fromJson(Map<String, dynamic> j) => DreamDetail(
    dream: Dream.fromJson(j['dream'] as Map<String, dynamic>),
    coinStats: j['coinStats'] is Map<String, dynamic>
        ? CoinStats.fromJson(j['coinStats'] as Map<String, dynamic>)
        : null,
    supporters: ((j['supporters'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(DreamSupporter.fromJson)
        .toList(),
  );
}

class DreamPage {
  final List<Dream> dreams;
  final int? nextCursor;
  final bool coinLaunchesEnabled;

  const DreamPage({
    required this.dreams,
    required this.nextCursor,
    required this.coinLaunchesEnabled,
  });

  factory DreamPage.fromJson(Map<String, dynamic> j) => DreamPage(
    dreams: ((j['dreams'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Dream.fromJson)
        .toList(),
    nextCursor: (j['nextCursor'] as num?)?.toInt(),
    coinLaunchesEnabled: j['coinLaunchesEnabled'] as bool? ?? false,
  );
}

/// A transaction built by the server, ready for the user's wallet to sign.
class ServerBuiltTx {
  final String transaction;
  final String? mint;
  final String? pool;
  final String? expectedOut;
  final String? minimumOut;

  const ServerBuiltTx({
    required this.transaction,
    this.mint,
    this.pool,
    this.expectedOut,
    this.minimumOut,
  });

  factory ServerBuiltTx.fromJson(Map<String, dynamic> j) => ServerBuiltTx(
    transaction: j['transaction'] as String,
    mint: j['mint'] as String?,
    pool: j['pool'] as String?,
    expectedOut: j['expectedOut'] as String?,
    minimumOut: j['minimumOut'] as String?,
  );
}
