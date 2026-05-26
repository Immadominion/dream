/// Category governs icon, color accent, and feed section.
enum AppNotifCategory {
  /// Order fills, TP/SL triggers, limit order executions.
  trade,

  /// User-set price-level alerts.
  alert,

  /// Margin / liquidation warnings.
  risk,

  /// Connectivity, maintenance, system status.
  system,

  /// App announcements, bounties, events, feature launches.
  marketing,

  /// AI intelligence decisions and signals (future).
  intelligence,
}

class AppNotification {
  final String id;
  final AppNotifCategory category;
  final String title;
  final String body;
  final DateTime timestamp;
  bool isRead;

  /// Optional deep-link payload — e.g. a market symbol like `"SOL-PERP"`.
  final String? payload;

  AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.payload,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        category: category,
        title: title,
        body: body,
        timestamp: timestamp,
        isRead: isRead ?? this.isRead,
        payload: payload,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
        'title': title,
        'body': body,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'isRead': isRead,
        'payload': payload,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        category: AppNotifCategory.values.firstWhere(
          (c) => c.name == json['category'],
          orElse: () => AppNotifCategory.system,
        ),
        title: json['title'] as String,
        body: json['body'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          json['timestamp'] as int,
        ),
        isRead: json['isRead'] as bool? ?? false,
        payload: json['payload'] as String?,
      );
}
