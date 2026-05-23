import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

import '../constants/app_constants.dart';
import 'logger_service.dart';

/// Provider for WebSocket service
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final logger = ref.watch(loggerServiceProvider);
  return WebSocketService(logger);
});

/// WebSocket connection states
enum WebSocketState { disconnected, connecting, connected, reconnecting, error }

/// WebSocket service for real-time communication
class WebSocketService {
  final LoggerService _logger;

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  final _stateController = StreamController<WebSocketState>.broadcast();
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  WebSocketState _currentState = WebSocketState.disconnected;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 5);
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  WebSocketService(this._logger);

  /// Current connection state
  WebSocketState get state => _currentState;

  /// Stream of connection state changes
  Stream<WebSocketState> get stateStream => _stateController.stream;

  /// Stream of incoming messages
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// Check if currently connected
  bool get isConnected => _currentState == WebSocketState.connected;

  /// Connect to WebSocket server
  Future<void> connect() async {
    if (_currentState == WebSocketState.connected ||
        _currentState == WebSocketState.connecting) {
      return;
    }

    _updateState(WebSocketState.connecting);
    _logger.info(
      'Connecting to WebSocket: ${AppConstants.bagsWebSocketUrl}',
      tag: 'WebSocket',
    );

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(AppConstants.bagsWebSocketUrl),
        protocols: ['bags-protocol'], // Add specific protocol if needed
      );

      await _channel?.ready;

      _updateState(WebSocketState.connected);
      _reconnectAttempts = 0;

      _logger.info('WebSocket connected successfully', tag: 'WebSocket');

      // Start listening to messages
      _listenToMessages();

      // Start heartbeat
      _startHeartbeat();
    } catch (error) {
      _logger.error(
        'WebSocket connection failed',
        error: error,
        tag: 'WebSocket',
      );
      _updateState(WebSocketState.error);
      _scheduleReconnect();
    }
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    _logger.info('Disconnecting WebSocket', tag: 'WebSocket');

    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();

    await _channel?.sink.close(status.goingAway);
    _channel = null;

    _updateState(WebSocketState.disconnected);
  }

  /// Send message through WebSocket
  void sendMessage(Map<String, dynamic> message) {
    if (!isConnected) {
      _logger.warning(
        'Cannot send message: WebSocket not connected',
        tag: 'WebSocket',
      );
      return;
    }

    try {
      final jsonMessage = jsonEncode(message);
      _channel?.sink.add(jsonMessage);
      _logger.debug('Sent WebSocket message: $jsonMessage', tag: 'WebSocket');
    } catch (error) {
      _logger.error(
        'Failed to send WebSocket message',
        error: error,
        tag: 'WebSocket',
      );
    }
  }

  /// Subscribe to specific event types
  Stream<Map<String, dynamic>> subscribeToEvent(String eventType) {
    return messageStream.where((message) => message['type'] == eventType);
  }

  /// Subscribe to token-specific events
  void subscribeToToken(String tokenAddress) {
    sendMessage({
      'action': 'subscribe',
      'type': 'token',
      'data': {'address': tokenAddress},
    });
  }

  /// Unsubscribe from token events
  void unsubscribeFromToken(String tokenAddress) {
    sendMessage({
      'action': 'unsubscribe',
      'type': 'token',
      'data': {'address': tokenAddress},
    });
  }

  /// Subscribe to user-specific events
  void subscribeToUser(String userId) {
    sendMessage({
      'action': 'subscribe',
      'type': 'user',
      'data': {'userId': userId},
    });
  }

  void _listenToMessages() {
    _channel?.stream.listen(
      (dynamic message) {
        try {
          final Map<String, dynamic> parsedMessage = jsonDecode(
            message as String,
          );
          _logger.debug(
            'Received WebSocket message: $parsedMessage',
            tag: 'WebSocket',
          );
          _messageController.add(parsedMessage);
        } catch (error) {
          _logger.error(
            'Failed to parse WebSocket message',
            error: error,
            tag: 'WebSocket',
          );
        }
      },
      onError: (error) {
        _logger.error('WebSocket stream error', error: error, tag: 'WebSocket');
        _handleConnectionError(error);
      },
      onDone: () {
        _logger.info('WebSocket connection closed', tag: 'WebSocket');
        if (_currentState == WebSocketState.connected) {
          _handleConnectionError('Connection closed unexpectedly');
        }
      },
    );
  }

  void _handleConnectionError(dynamic error) {
    _heartbeatTimer?.cancel();

    if (_currentState != WebSocketState.disconnected) {
      _updateState(WebSocketState.error);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _logger.error('Max reconnection attempts reached', tag: 'WebSocket');
      _updateState(WebSocketState.disconnected);
      return;
    }

    _reconnectAttempts++;
    _updateState(WebSocketState.reconnecting);

    _logger.info(
      'Scheduling reconnect attempt $_reconnectAttempts in ${_reconnectDelay.inSeconds}s',
      tag: 'WebSocket',
    );

    _reconnectTimer = Timer(_reconnectDelay, () {
      if (_currentState != WebSocketState.disconnected) {
        connect();
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (isConnected) {
        sendMessage({
          'type': 'ping',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
  }

  void _updateState(WebSocketState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _stateController.add(newState);
      _logger.debug('WebSocket state changed to: $newState', tag: 'WebSocket');
    }
  }

  /// Clean up resources
  void dispose() {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _stateController.close();
    _messageController.close();
  }
}
