import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'logger_service.dart';

/// Provider for error handler service
final errorHandlerProvider = Provider<ErrorHandlerService>((ref) {
  final logger = ref.watch(loggerServiceProvider);
  return ErrorHandlerService(logger);
});

/// Custom exception classes
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  const ApiException(this.message, {this.statusCode, this.originalError});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class NetworkException implements Exception {
  final String message;
  final dynamic originalError;

  const NetworkException(this.message, {this.originalError});

  @override
  String toString() => 'NetworkException: $message';
}

class AuthenticationException implements Exception {
  final String message;
  final dynamic originalError;

  const AuthenticationException(this.message, {this.originalError});

  @override
  String toString() => 'AuthenticationException: $message';
}

class ValidationException implements Exception {
  final String message;
  final Map<String, String>? fieldErrors;

  const ValidationException(this.message, {this.fieldErrors});

  @override
  String toString() => 'ValidationException: $message';
}

class StorageException implements Exception {
  final String message;
  final dynamic originalError;

  const StorageException(this.message, {this.originalError});

  @override
  String toString() => 'StorageException: $message';
}

/// Centralized error handling service
class ErrorHandlerService {
  final LoggerService _logger;

  ErrorHandlerService(this._logger);

  /// Handle and log errors with appropriate actions
  String handleError(Object error, {StackTrace? stackTrace, String? context}) {
    String userMessage;

    switch (error) {
      case ApiException apiError:
        userMessage = _handleApiError(apiError);
      case NetworkException networkError:
        userMessage = _handleNetworkError(networkError);
      case AuthenticationException authError:
        userMessage = _handleAuthError(authError);
      case ValidationException validationError:
        userMessage = _handleValidationError(validationError);
      case StorageException storageError:
        userMessage = _handleStorageError(storageError);
      default:
        userMessage = _handleGenericError(error);
    }

    // Log the error
    _logger.error(
      '${context ?? 'Error'}: $userMessage',
      error: error,
      stackTrace: stackTrace,
      tag: 'ErrorHandler',
    );

    return userMessage;
  }

  String _handleApiError(ApiException error) {
    switch (error.statusCode) {
      case 400:
        return 'Invalid request. Please check your input.';
      case 401:
        return 'Authentication required. Please log in again.';
      case 403:
        return 'Access denied. You don\'t have permission for this action.';
      case 404:
        return 'Requested resource not found.';
      case 429:
        return 'Too many requests. Please try again later.';
      case 500:
        return 'Server error. Please try again later.';
      default:
        return error.message.isNotEmpty
            ? error.message
            : 'An API error occurred.';
    }
  }

  String _handleNetworkError(NetworkException error) {
    return 'Network error. Please check your internet connection and try again.';
  }

  String _handleAuthError(AuthenticationException error) {
    return 'Authentication failed. Please log in again.';
  }

  String _handleValidationError(ValidationException error) {
    return error.message.isNotEmpty ? error.message : 'Validation failed.';
  }

  String _handleStorageError(StorageException error) {
    return 'Storage error. Please restart the app and try again.';
  }

  String _handleGenericError(Object error) {
    return 'An unexpected error occurred. Please try again.';
  }

  /// Report critical errors for monitoring
  void reportCriticalError(
    Object error,
    StackTrace stackTrace, {
    String? context,
  }) {
    _logger.error(
      'CRITICAL ERROR ${context ?? ''}: ${error.toString()}',
      error: error,
      stackTrace: stackTrace,
      tag: 'CRITICAL',
    );

    // In production, you would send this to crash reporting service
    // e.g., FirebaseCrashlytics, Sentry, etc.
  }

  /// Check if error should retry
  bool shouldRetry(Object error) {
    if (error is ApiException) {
      return error.statusCode != null &&
          (error.statusCode! >= 500 || error.statusCode == 429);
    }
    if (error is NetworkException) {
      return true;
    }
    return false;
  }

  /// Get retry delay based on error type
  Duration getRetryDelay(Object error, int retryCount) {
    if (error is ApiException && error.statusCode == 429) {
      // Exponential backoff for rate limiting
      return Duration(seconds: (retryCount * 2).clamp(1, 30));
    }
    if (error is NetworkException) {
      // Linear backoff for network errors
      return Duration(seconds: (retryCount * 3).clamp(3, 15));
    }
    return const Duration(seconds: 5);
  }
}
