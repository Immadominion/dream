import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import 'logger_service.dart';
import '../../shared/models/api_response.dart';
import '../../shared/services/storage_service.dart';

/// Provider for API service
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

/// HTTP client service for API communication
class ApiService {
  late final Dio _dio;
  final _logger = LoggerService();

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: AppConstants.apiTimeout,
        receiveTimeout: AppConstants.apiTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _setupInterceptors();
  }

  /// Setup request/response interceptors
  void _setupInterceptors() {
    // Request interceptor for adding server-issued access token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = StorageService.userToken;
            if (token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (e) {
            // Continue without token if storage lookup fails
            _logger.warning('[API] Failed to get stored auth token: $e');
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // Handle 401 unauthorized
          if (error.response?.statusCode == 401) {
            await StorageService.clearUserData();
            await StorageService.setString(StorageService.userTokenKey, '');
            // Could trigger navigation to login here
          }
          handler.next(error);
        },
      ),
    );

    // Logging interceptor (only in debug mode)
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: false,
        responseHeader: false,
      ),
    );
  }

  /// Generic GET request
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final uri = _resolveUri(endpoint, queryParams);
      final response = await _dio.getUri(uri);

      if (response.statusCode == 200) {
        if (fromJson != null && response.data is Map<String, dynamic>) {
          final data = fromJson(response.data as Map<String, dynamic>);
          return ApiResponse.success(data);
        } else {
          return ApiResponse.success(response.data as T);
        }
      } else {
        return ApiResponse.failure(
          'Request failed with status: ${response.statusCode}',
          response.statusCode,
        );
      }
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiResponse.failure(e.toString());
    }
  }

  /// Generic POST request
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParams,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final uri = _resolveUri(endpoint, queryParams);
      final response = await _dio.postUri(uri, data: data);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (fromJson != null && response.data is Map<String, dynamic>) {
          final responseData = fromJson(response.data as Map<String, dynamic>);
          return ApiResponse.success(responseData);
        } else {
          return ApiResponse.success(response.data as T);
        }
      } else {
        return ApiResponse.failure(
          'Request failed with status: ${response.statusCode}',
          response.statusCode,
        );
      }
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiResponse.failure(e.toString());
    }
  }

  /// Generic PUT request
  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParams,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final uri = _resolveUri(endpoint, queryParams);
      final response = await _dio.putUri(uri, data: data);

      if (response.statusCode == 200) {
        if (fromJson != null && response.data is Map<String, dynamic>) {
          final responseData = fromJson(response.data as Map<String, dynamic>);
          return ApiResponse.success(responseData);
        } else {
          return ApiResponse.success(response.data as T);
        }
      } else {
        return ApiResponse.failure(
          'Request failed with status: ${response.statusCode}',
          response.statusCode,
        );
      }
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiResponse.failure(e.toString());
    }
  }

  /// Generic DELETE request
  Future<ApiResponse<bool>> delete(
    String endpoint, {
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final uri = _resolveUri(endpoint, queryParams);
      final response = await _dio.deleteUri(uri);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResponse.success(true);
      } else {
        return ApiResponse.failure(
          'Delete failed with status: ${response.statusCode}',
          response.statusCode,
        );
      }
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiResponse.failure(e.toString());
    }
  }

  /// Handle Dio errors consistently
  ApiResponse<T> _handleDioError<T>(DioException error) {
    String errorMessage;
    int? statusCode = error.response?.statusCode;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        errorMessage = 'Connection timeout';
        break;
      case DioExceptionType.receiveTimeout:
        errorMessage = 'Receive timeout';
        break;
      case DioExceptionType.badResponse:
        errorMessage =
            error.response?.data?['message'] ?? 'Server error occurred';
        break;
      case DioExceptionType.cancel:
        errorMessage = 'Request was cancelled';
        break;
      case DioExceptionType.unknown:
        errorMessage = 'Network error occurred';
        break;
      default:
        errorMessage = 'An unexpected error occurred';
    }

    return ApiResponse.failure(errorMessage, statusCode);
  }

  Uri _resolveUri(String endpoint, Map<String, dynamic>? queryParams) {
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      final uri = Uri.parse(endpoint);
      return _withQuery(uri, queryParams);
    }

    final sanitizedEndpoint = _normalizeEndpoint(endpoint);
    final uri = AppConstants.apiUri(sanitizedEndpoint);
    return _withQuery(uri, queryParams);
  }

  String _normalizeEndpoint(String endpoint) {
    var trimmed = endpoint.trim();
    if (trimmed.startsWith('/')) {
      trimmed = trimmed.substring(1);
    }
    if (trimmed.isEmpty) {
      return 'v1';
    }
    if (!trimmed.startsWith('v1/')) {
      return 'v1/$trimmed';
    }
    return trimmed;
  }

  Uri _withQuery(Uri base, Map<String, dynamic>? queryParams) {
    if (queryParams == null || queryParams.isEmpty) {
      return base;
    }

    final params = Map<String, String>.from(base.queryParameters);
    queryParams.forEach((key, value) {
      if (value == null) return;
      params[key] = value.toString();
    });

    return base.replace(queryParameters: params);
  }
}
