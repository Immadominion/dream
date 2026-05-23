import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../constants/app_constants.dart';
import '../../models/phoenix/phoenix_models.dart';
import '../logger_service.dart';

final phoenixWebSocketServiceProvider = Provider<PhoenixWebSocketService>((
  ref,
) {
  final logger = ref.watch(loggerServiceProvider);
  final svc = PhoenixWebSocketService(logger: logger);
  ref.onDispose(svc.disconnect);
  return svc;
});

// ---------------------------------------------------------------------------
// Typed WS messages
// ---------------------------------------------------------------------------

class AllMidsMessage {
  /// symbol → mark price (USD)
  final Map<String, double> mids;
  const AllMidsMessage(this.mids);
}

class MarketSnapshotMessage {
  final PhoenixMarketSnapshot snapshot;
  const MarketSnapshotMessage(this.snapshot);
}

class TraderStateMessage {
  final Map<String, dynamic> raw;
  const TraderStateMessage(this.raw);
}

class OrderbookMessage {
  final PhoenixOrderbook orderbook;
  const OrderbookMessage(this.orderbook);
}

class CandleMessage {
  final String symbol;
  final String timeframe;
  final PhoenixCandle candle;
  const CandleMessage({
    required this.symbol,
    required this.timeframe,
    required this.candle,
  });
}

class RecentTradesMessage {
  final String symbol;
  final List<PhoenixRecentTrade> trades;
  const RecentTradesMessage({required this.symbol, required this.trades});
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Manages a single WebSocket connection to Phoenix perp-api.
///
/// Channels supported:
///   - `allMids`     → price updates for all markets
///   - `market`      → per-symbol snapshots (markPx, OI, funding, etc.)
///   - `traderState` → account + position updates for an authority
///
/// Call [connect] once after Phoenix auth is ready, then use the typed
/// streams. Subscribe to specific channels with [subscribeMarket] /
/// [subscribeTraderState] after connecting.
class PhoenixWebSocketService {
  final LoggerService _logger;

  WebSocketChannel? _channel;
  bool _connected = false;
  bool _disposed = false;

  // reconnect backoff
  int _reconnectAttempts = 0;
  static const _maxReconnectDelay = Duration(seconds: 60);

  // heartbeat
  Timer? _pingTimer;
  Timer? _pongTimeoutTimer;
  static const _pingInterval = Duration(seconds: 30);
  static const _pongTimeout = Duration(seconds: 10);
  DateTime? _lastMessageAt;

  // Typed broadcast streams
  final _allMidsController = StreamController<AllMidsMessage>.broadcast();
  final _marketController = StreamController<MarketSnapshotMessage>.broadcast();
  final _traderStateController =
      StreamController<TraderStateMessage>.broadcast();
  final _orderbookController = StreamController<OrderbookMessage>.broadcast();
  final _candleController = StreamController<CandleMessage>.broadcast();
  final _tradesController = StreamController<RecentTradesMessage>.broadcast();
  final _connectionStatusController = StreamController<bool>.broadcast();

  /// Live mid-price updates for all symbols.
  Stream<AllMidsMessage> get allMidsStream => _allMidsController.stream;

  /// Per-symbol market snapshots (after calling [subscribeMarket]).
  Stream<MarketSnapshotMessage> get marketStream => _marketController.stream;

  /// Trader state updates (after calling [subscribeTraderState]).
  Stream<TraderStateMessage> get traderStateStream =>
      _traderStateController.stream;

  /// Live orderbook updates (after calling [subscribeOrderbook]).
  Stream<OrderbookMessage> get orderbookStream => _orderbookController.stream;

  /// Live candle updates (after calling [subscribeCandles]).
  Stream<CandleMessage> get candleStream => _candleController.stream;

  /// Recent trades feed (after calling [subscribeTrades]).
  Stream<RecentTradesMessage> get tradesStream => _tradesController.stream;

  /// Emits `true` when connected, `false` when disconnected.
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  // Track active subscriptions so we can re-subscribe after reconnects
  final Set<String> _subscribedMarkets = {};
  String? _subscribedAuthority;
  final Set<String> _subscribedOrderbooks = {};
  final Map<String, String> _subscribedCandles = {}; // symbol → timeframe
  final Set<String> _subscribedTrades = {};

  PhoenixWebSocketService({required LoggerService logger}) : _logger = logger;

  bool get isConnected => _connected;

  // ---------------------------------------------------------------------------
  // Connection management
  // ---------------------------------------------------------------------------

  Future<void> connect() async {
    if (_connected || _disposed) return;
    try {
      _logger.info('Connecting to Phoenix WS', tag: 'WS');
      _channel = WebSocketChannel.connect(Uri.parse(AppConstants.phoenixWsUrl));
      await _channel!.ready;
      _connected = true;
      _reconnectAttempts = 0;
      _logger.info('Phoenix WS connected', tag: 'WS');
      if (!_connectionStatusController.isClosed) {
        _connectionStatusController.add(true);
      }

      // Always subscribe to allMids on connection
      _send({
        'type': 'subscribe',
        'subscription': {'channel': 'allMids'},
      });

      // Re-subscribe to active channels after reconnect
      for (final symbol in _subscribedMarkets) {
        _sendMarketSub(symbol);
      }
      if (_subscribedAuthority != null) {
        _sendTraderSub(_subscribedAuthority!);
      }
      for (final symbol in _subscribedOrderbooks) {
        _sendOrderbookSub(symbol);
      }
      for (final entry in _subscribedCandles.entries) {
        _sendCandlesSub(entry.key, entry.value);
      }
      for (final symbol in _subscribedTrades) {
        _sendTradesSub(symbol);
      }

      _channel!.stream.listen(
        _onMessage,
        onDone: _onDisconnect,
        onError: _onError,
        cancelOnError: false,
      );

      _startHeartbeat();
    } catch (e) {
      _logger.error('WS connect failed', error: e, tag: 'WS');
      _connected = false;
      _scheduleReconnect();
    }
  }

  void disconnect() {
    _disposed = true;
    _connected = false;
    _stopHeartbeat();
    _channel?.sink.close();
    _channel = null;
    _allMidsController.close();
    _marketController.close();
    _traderStateController.close();
    _orderbookController.close();
    _candleController.close();
    _tradesController.close();
    _connectionStatusController.close();
    _logger.info('Phoenix WS disconnected', tag: 'WS');
  }

  // ---------------------------------------------------------------------------
  // Channel subscriptions
  // ---------------------------------------------------------------------------

  /// Subscribe to per-symbol market data (markPx, OI, funding, etc.)
  void subscribeMarket(String symbol) {
    _subscribedMarkets.add(symbol);
    if (_connected) _sendMarketSub(symbol);
  }

  void unsubscribeMarket(String symbol) {
    _subscribedMarkets.remove(symbol);
    if (_connected) {
      _send({
        'type': 'unsubscribe',
        'subscription': {'channel': 'market', 'symbol': _toApiSymbol(symbol)},
      });
    }
  }

  /// Subscribe to real-time trader state updates for [authority].
  void subscribeTraderState(String authority) {
    _subscribedAuthority = authority;
    if (_connected) _sendTraderSub(authority);
  }

  void unsubscribeTraderState() {
    if (_subscribedAuthority != null && _connected) {
      _send({
        'type': 'unsubscribe',
        'subscription': {
          'channel': 'traderState',
          'authority': _subscribedAuthority,
        },
      });
    }
    _subscribedAuthority = null;
  }

  /// Subscribe to live orderbook for [symbol] (e.g. "SOL-PERP").
  void subscribeOrderbook(String symbol) {
    _subscribedOrderbooks.add(symbol);
    if (_connected) _sendOrderbookSub(symbol);
  }

  void unsubscribeOrderbook(String symbol) {
    _subscribedOrderbooks.remove(symbol);
    if (_connected) {
      _send({
        'type': 'unsubscribe',
        'subscription': {
          'channel': 'orderbook',
          'symbol': _toApiSymbol(symbol),
        },
      });
    }
  }

  /// Subscribe to live candle updates for [symbol] at [timeframe].
  void subscribeCandles(String symbol, String timeframe) {
    _subscribedCandles[symbol] = timeframe;
    if (_connected) _sendCandlesSub(symbol, timeframe);
  }

  void unsubscribeCandles(String symbol) {
    final tf = _subscribedCandles.remove(symbol);
    if (tf != null && _connected) {
      _send({
        'type': 'unsubscribe',
        'subscription': {
          'channel': 'candles',
          'symbol': _toApiSymbol(symbol),
          'timeframe': tf,
        },
      });
    }
  }

  /// Subscribe to live recent trades for [symbol].
  void subscribeTrades(String symbol) {
    _subscribedTrades.add(symbol);
    if (_connected) _sendTradesSub(symbol);
  }

  void unsubscribeTrades(String symbol) {
    _subscribedTrades.remove(symbol);
    if (_connected) {
      _send({
        'type': 'unsubscribe',
        'subscription': {'channel': 'trades', 'symbol': _toApiSymbol(symbol)},
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Message handling
  // ---------------------------------------------------------------------------

  void _onMessage(dynamic raw) {
    _lastMessageAt = DateTime.now();
    // Cancel pending pong timeout — server is alive
    _pongTimeoutTimer?.cancel();
    _pongTimeoutTimer = null;
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final channel = data['channel'] as String? ?? '';

      switch (channel) {
        case 'allMids':
          final midsRaw = data['mids'] as Map<String, dynamic>? ?? {};
          // Phoenix WS allMids uses short symbols ("SOL"), normalize to "SOL-PERP"
          final mids = midsRaw.map(
            (k, v) => MapEntry(
              k.endsWith('-PERP') ? k : '$k-PERP',
              (v as num).toDouble(),
            ),
          );
          if (!_allMidsController.isClosed) {
            _allMidsController.add(AllMidsMessage(mids));
          }

        case 'market':
          final snapshot = PhoenixMarketSnapshot.fromWsMarket(data);
          if (!_marketController.isClosed) {
            _marketController.add(MarketSnapshotMessage(snapshot));
          }

        case 'traderState':
          if (!_traderStateController.isClosed) {
            _traderStateController.add(TraderStateMessage(data));
          }

        case 'orderbook':
          if (!_orderbookController.isClosed) {
            final ob = PhoenixOrderbook.fromWs(data);
            _orderbookController.add(OrderbookMessage(ob));
          }

        case 'candle':
          if (!_candleController.isClosed) {
            final sym = data['symbol'] as String? ?? '';
            final tf = data['timeframe'] as String? ?? '';
            final candleData = data['candle'] as Map<String, dynamic>?;
            if (candleData != null) {
              _candleController.add(
                CandleMessage(
                  symbol: sym.endsWith('-PERP') ? sym : '$sym-PERP',
                  timeframe: tf,
                  candle: PhoenixCandle.fromJson(candleData),
                ),
              );
            }
          }

        case 'trades':
          if (!_tradesController.isClosed) {
            final sym = data['symbol'] as String? ?? '';
            final normalizedSym = sym.endsWith('-PERP') ? sym : '$sym-PERP';
            final tradesRaw = data['trades'] as List<dynamic>? ?? [];
            final trades = tradesRaw
                .map(
                  (t) => PhoenixRecentTrade.fromJson(
                    normalizedSym,
                    t as Map<String, dynamic>,
                  ),
                )
                .toList();
            _tradesController.add(
              RecentTradesMessage(symbol: normalizedSym, trades: trades),
            );
          }

        default:
          break; // ignore unknown channels
      }
    } catch (e) {
      _logger.error('WS message parse error', error: e, tag: 'WS');
    }
  }

  void _onDisconnect() {
    _connected = false;
    _stopHeartbeat();
    _logger.warning('Phoenix WS disconnected', tag: 'WS');
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add(false);
    }
    if (!_disposed) _scheduleReconnect();
  }

  void _onError(Object error) {
    _connected = false;
    _stopHeartbeat();
    _logger.error('Phoenix WS error', error: error, tag: 'WS');
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add(false);
    }
    if (!_disposed) _scheduleReconnect();
  }

  // ---------------------------------------------------------------------------
  // Heartbeat — detect silent connection drops (common on mobile)
  // ---------------------------------------------------------------------------

  void _startHeartbeat() {
    _stopHeartbeat();
    _pingTimer = Timer.periodic(_pingInterval, (_) => _sendPing());
  }

  void _stopHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _pongTimeoutTimer?.cancel();
    _pongTimeoutTimer = null;
  }

  void _sendPing() {
    if (!_connected || _disposed) return;

    // If no message arrived in the last ping interval, the connection may be
    // silently stale. Send a ping and wait for any response.
    final idleSince = _lastMessageAt;
    if (idleSince != null) {
      final idle = DateTime.now().difference(idleSince);
      if (idle < _pingInterval) return; // server is still active
    }

    try {
      // Phoenix WS doesn't define a ping frame — send a no-op subscribe to
      // allMids which the server echoes immediately.
      _channel?.sink.add(
        jsonEncode({
          'type': 'subscribe',
          'subscription': {'channel': 'allMids'},
        }),
      );
      _logger.debug('WS ping sent', tag: 'WS');
    } catch (e) {
      _logger.warning('WS ping failed: $e', tag: 'WS');
    }

    // If we don't get any response within pongTimeout, force reconnect
    _pongTimeoutTimer = Timer(_pongTimeout, () {
      if (!_connected || _disposed) return;
      _logger.warning('WS pong timeout — forcing reconnect', tag: 'WS');
      _connected = false;
      _stopHeartbeat();
      _channel?.sink.close();
      if (!_connectionStatusController.isClosed) {
        _connectionStatusController.add(false);
      }
      _scheduleReconnect();
    });
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectAttempts++;
    final delay = Duration(
      seconds: (2 << _reconnectAttempts.clamp(0, 5)).clamp(
        2,
        _maxReconnectDelay.inSeconds,
      ),
    );
    _logger.info('WS reconnect in ${delay.inSeconds}s', tag: 'WS');
    Future.delayed(delay, connect);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _send(Map<String, dynamic> payload) {
    if (!_connected) return;
    _channel?.sink.add(jsonEncode(payload));
  }

  void _sendMarketSub(String symbol) {
    _send({
      'type': 'subscribe',
      'subscription': {'channel': 'market', 'symbol': _toApiSymbol(symbol)},
    });
  }

  void _sendTraderSub(String authority) {
    _send({
      'type': 'subscribe',
      'subscription': {
        'channel': 'traderState',
        'authority': authority,
        'traderPdaIndex': 0,
      },
    });
  }

  void _sendOrderbookSub(String symbol) {
    _send({
      'type': 'subscribe',
      'subscription': {'channel': 'orderbook', 'symbol': _toApiSymbol(symbol)},
    });
  }

  void _sendCandlesSub(String symbol, String timeframe) {
    _send({
      'type': 'subscribe',
      'subscription': {
        'channel': 'candles',
        'symbol': _toApiSymbol(symbol),
        'timeframe': timeframe,
      },
    });
  }

  void _sendTradesSub(String symbol) {
    _send({
      'type': 'subscribe',
      'subscription': {'channel': 'trades', 'symbol': _toApiSymbol(symbol)},
    });
  }

  /// Strip "-PERP" suffix for WS subscription channels that use short symbols.
  String _toApiSymbol(String symbol) => symbol.endsWith('-PERP')
      ? symbol.substring(0, symbol.length - 5)
      : symbol;
}
