import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../../core/constants/app_constants.dart';
import '../models/api_response.dart';
import 'storage_service.dart';

/// Base API service for handling HTTP requests to Bags.FM API
class ApiService {
  static ApiService? _instance;
  late final Dio _dio;

  ApiService._() {
    _dio = Dio(_getBaseOptions());
    _setupInterceptors();
  }

  static ApiService get instance => _instance ??= ApiService._();

  Dio get dio => _dio;

  BaseOptions _getBaseOptions() {
    return BaseOptions(
      baseUrl: AppConstants.bagsApiBaseUrl,
      connectTimeout: AppConstants.apiTimeout,
      receiveTimeout: AppConstants.apiTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
  }

  void _setupInterceptors() {
    // Add pretty logger for development
    _dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        compact: true,
      ),
    );

    // Add authentication interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Add API key to headers if available
          final apiKey = StorageService.getString('api_key');
          if (apiKey.isNotEmpty) {
            options.headers['x-api-key'] = apiKey;
            options.headers['Authorization'] = 'Bearer $apiKey';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          // Handle common errors
          if (error.response?.statusCode == 401) {
            // Handle unauthorized - clear stored tokens
            StorageService.setString('api_key', '');
            // Could trigger logout here
          }
          handler.next(error);
        },
      ),
    );
  }

  // Generic GET request
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return _handleError<T>(e);
    }
  }

  // Generic POST request
  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return _handleError<T>(e);
    }
  }

  // Generic PUT request
  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return _handleError<T>(e);
    }
  }

  // Generic DELETE request
  Future<ApiResponse<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        queryParameters: queryParameters,
        options: options,
      );

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return _handleError<T>(e);
    }
  }

  // File upload
  Future<ApiResponse<T>> uploadFile<T>(
    String path,
    String filePath, {
    String? fileName,
    Map<String, dynamic>? data,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
        ...?data,
      });

      final response = await _dio.post(path, data: formData);

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return _handleError<T>(e);
    }
  }

  // Handle successful response
  ApiResponse<T> _handleResponse<T>(
    Response response,
    T Function(Map<String, dynamic>)? fromJson,
  ) {
    if (response.statusCode! >= 200 && response.statusCode! < 300) {
      final data = response.data;

      if (fromJson != null && data is Map<String, dynamic>) {
        return ApiResponse.success(fromJson(data));
      }

      return ApiResponse.success(data as T);
    }

    return ApiResponse.failure(
      'Request failed with status: ${response.statusCode}',
      response.statusCode,
    );
  }

  // Handle error
  ApiResponse<T> _handleError<T>(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return ApiResponse.failure(
            'Connection timeout. Please check your internet connection.',
            error.response?.statusCode,
          );
        case DioExceptionType.badResponse:
          return ApiResponse.failure(
            error.response?.data?['message'] ?? 'Server error occurred',
            error.response?.statusCode,
          );
        case DioExceptionType.cancel:
          return ApiResponse.failure('Request was cancelled');
        case DioExceptionType.connectionError:
          return ApiResponse.failure(
            'No internet connection. Please check your network.',
          );
        default:
          return ApiResponse.failure(
            error.message ?? 'An unexpected error occurred',
          );
      }
    }

    return ApiResponse.failure('An unexpected error occurred: $error');
  }

  // Update API key
  void updateApiKey(String apiKey) {
    StorageService.setString('api_key', apiKey);
    _dio.options.headers['x-api-key'] = apiKey;
    _dio.options.headers['Authorization'] = 'Bearer $apiKey';
  }

  // Clear API key
  void clearApiKey() {
    StorageService.setString('api_key', '');
    _dio.options.headers.remove('x-api-key');
    _dio.options.headers.remove('Authorization');
  }
}
