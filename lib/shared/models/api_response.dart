import 'package:equatable/equatable.dart';

/// Generic API response wrapper
class ApiResponse<T> extends Equatable {
  final bool isSuccess;
  final T? data;
  final String? message;
  final int? statusCode;
  final String? error;

  const ApiResponse._({
    required this.isSuccess,
    this.data,
    this.message,
    this.statusCode,
    this.error,
  });

  /// Create a successful response
  factory ApiResponse.success(T data, {String? message}) {
    return ApiResponse._(isSuccess: true, data: data, message: message);
  }

  /// Create a failure response
  factory ApiResponse.failure(String error, [int? statusCode]) {
    return ApiResponse._(
      isSuccess: false,
      error: error,
      statusCode: statusCode,
    );
  }

  /// Create a loading state (optional)
  factory ApiResponse.loading({String? message}) {
    return ApiResponse._(isSuccess: false, message: message ?? 'Loading...');
  }

  /// Check if response is successful
  bool get isFailure => !isSuccess;

  /// Get error message for display
  String get errorMessage => error ?? 'Unknown error occurred';

  /// Convert to string for debugging
  @override
  String toString() {
    if (isSuccess) {
      return 'ApiResponse.success(data: $data, message: $message)';
    } else {
      return 'ApiResponse.failure(error: $error, statusCode: $statusCode)';
    }
  }

  @override
  List<Object?> get props => [isSuccess, data, message, statusCode, error];
}
