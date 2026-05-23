import 'package:equatable/equatable.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

enum AlertDirection { above, below }

class PriceAlert extends Equatable {
  final String id;
  final String symbol; // e.g. "SOL-PERP"
  final double targetPrice;
  final AlertDirection direction;
  final bool triggered;

  const PriceAlert({
    required this.id,
    required this.symbol,
    required this.targetPrice,
    required this.direction,
    this.triggered = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'symbol': symbol,
    'targetPrice': targetPrice,
    'direction': direction.name,
    'triggered': triggered,
  };

  static PriceAlert fromJson(Map<String, dynamic> json) => PriceAlert(
    id: json['id'] as String,
    symbol: json['symbol'] as String,
    targetPrice: (json['targetPrice'] as num).toDouble(),
    direction: json['direction'] == 'above'
        ? AlertDirection.above
        : AlertDirection.below,
    triggered: json['triggered'] as bool? ?? false,
  );

  PriceAlert copyWith({bool? triggered}) => PriceAlert(
    id: id,
    symbol: symbol,
    targetPrice: targetPrice,
    direction: direction,
    triggered: triggered ?? this.triggered,
  );

  String get directionLabel => direction == AlertDirection.above ? '≥' : '≤';

  String get formattedPrice => targetPrice >= 1000
      ? '\$${targetPrice.toStringAsFixed(0)}'
      : '\$${targetPrice.toStringAsFixed(2)}';

  @override
  List<Object?> get props => [id, symbol, targetPrice, direction, triggered];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class PriceAlertsState {
  final List<PriceAlert> alerts;

  const PriceAlertsState({this.alerts = const []});

  PriceAlertsState copyWith({List<PriceAlert>? alerts}) =>
      PriceAlertsState(alerts: alerts ?? this.alerts);

  List<PriceAlert> activeAlerts(String symbol) =>
      alerts.where((a) => a.symbol == symbol && !a.triggered).toList();

  List<PriceAlert> get activeAll => alerts.where((a) => !a.triggered).toList();
}

// Provider is declared in providers/price_alerts_provider.dart
