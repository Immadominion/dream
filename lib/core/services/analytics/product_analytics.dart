import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Product analytics (Firebase Analytics).
///
/// Measures the funnels that decide whether V2 works:
///   Dreams: feed → dream viewed → posted / funded / coin launched / traded
///   Perps:  signup → deposit → first order
///
/// Rules: never log wallet addresses, emails, or free text; amounts are
/// logged as numbers (not personal data). Analytics must never break a flow,
/// so every call swallows its own errors.
abstract final class ProductAnalytics {
  static FirebaseAnalytics? _instance;

  static FirebaseAnalytics? get _fa {
    try {
      return _instance ??= FirebaseAnalytics.instance;
    } catch (_) {
      return null; // Firebase not initialized (tests, misconfig)
    }
  }

  /// Route observer for automatic screen_view events.
  static List<FirebaseAnalyticsObserver> get observers {
    final fa = _fa;
    return fa == null ? const [] : [FirebaseAnalyticsObserver(analytics: fa)];
  }

  static Future<void> _log(String name, [Map<String, Object>? params]) async {
    try {
      await _fa?.logEvent(name: name, parameters: params);
    } catch (e) {
      if (kDebugMode) debugPrint('[Analytics] $name failed: $e');
    }
  }

  // ── Perps funnel ──────────────────────────────────────────────────────────
  static Future<void> signedUp() => _log('sign_up');
  static Future<void> deposited(double usdc) =>
      _log('collateral_deposit', {'amount_usd': usdc});
  static Future<void> orderPlaced({
    required String market,
    required String side,
    required double notionalUsd,
  }) => _log('order_placed', {
    'market': market,
    'side': side,
    'notional_usd': notionalUsd,
  });
  static Future<void> positionClosed({required String market}) =>
      _log('position_closed', {'market': market});

  // ── Dreams funnel ─────────────────────────────────────────────────────────
  static Future<void> dreamsFeedViewed(String sort) =>
      _log('dreams_feed_viewed', {'sort': sort});
  static Future<void> dreamViewed({
    required String dreamId,
    required bool hasCoin,
    required bool isOwner,
  }) => _log('dream_viewed', {
    'dream_id': dreamId,
    'has_coin': hasCoin ? 1 : 0,
    'is_owner': isOwner ? 1 : 0,
  });
  static Future<void> dreamCreated({
    required String category,
    required double goalUsd,
  }) => _log('dream_created', {'category': category, 'goal_usd': goalUsd});
  static Future<void> dreamFunded(double amountUsd) =>
      _log('dream_funded', {'amount_usd': amountUsd});
  static Future<void> dreamFundFailed(String stage) =>
      _log('dream_fund_failed', {'stage': stage});
  static Future<void> coinLaunched() => _log('dream_coin_launched');
  static Future<void> coinTraded({required bool buy}) =>
      _log('dream_coin_traded', {'side': buy ? 'buy' : 'sell'});
  static Future<void> coinFeesClaimed() => _log('dream_coin_fees_claimed');
  static Future<void> xVerified() => _log('dream_x_verified');
  static Future<void> dreamShared() => _log('dream_shared');
  static Future<void> dreamReported(String reason) =>
      _log('dream_reported', {'reason': reason});
}
