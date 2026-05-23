import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for logging service
final loggerServiceProvider = Provider<LoggerService>((ref) {
  return LoggerService();
});

/// Centralized logging service
class LoggerService {
  static const String _tag = 'DreamLabs';

  /// Log debug messages (only in debug mode)
  void debug(String message, {String? tag}) {
    if (kDebugMode) {
      developer.log(
        message,
        name: tag ?? _tag,
        level: 500, // Debug level
      );
    }
  }

  /// Log info messages
  void info(String message, {String? tag}) {
    developer.log(
      message,
      name: tag ?? _tag,
      level: 800, // Info level
    );
  }

  /// Log warning messages
  void warning(String message, {String? tag}) {
    developer.log(
      message,
      name: tag ?? _tag,
      level: 900, // Warning level
    );
  }

  /// Log error messages
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    developer.log(
      message,
      name: tag ?? _tag,
      level: 1000, // Error level
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log API requests
  void apiRequest(String method, String url, {Map<String, dynamic>? data}) {
    if (kDebugMode) {
      debug(
        'API $method: $url ${data != null ? '- Data: $data' : ''}',
        tag: 'API',
      );
    }
  }

  /// Log API responses
  void apiResponse(String method, String url, int statusCode, {dynamic data}) {
    if (kDebugMode) {
      debug(
        'API $method: $url - Status: $statusCode ${data != null ? '- Response: $data' : ''}',
        tag: 'API',
      );
    }
  }

  /// Log navigation events
  void navigation(String route, {String? previousRoute}) {
    debug(
      'Navigation: ${previousRoute ?? 'Unknown'} -> $route',
      tag: 'Navigation',
    );
  }

  /// Log user actions
  void userAction(String action, {Map<String, dynamic>? data}) {
    debug(
      'User Action: $action ${data != null ? '- Data: $data' : ''}',
      tag: 'UserAction',
    );
  }

  /// Log performance metrics
  void performance(String operation, Duration duration) {
    debug(
      'Performance: $operation took ${duration.inMilliseconds}ms',
      tag: 'Performance',
    );
  }

  /// Log authentication events
  void auth(String event, {bool success = true, String? error}) {
    if (success) {
      info('Auth: $event successful', tag: 'Auth');
    } else {
      this.error(
        'Auth: $event failed - ${error ?? 'Unknown error'}',
        tag: 'Auth',
      );
    }
  }
}
