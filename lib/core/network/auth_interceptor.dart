import 'package:base_project/core/constants/storage_keys.dart';
import 'package:base_project/core/storage/secure_storage_service.dart';
import 'package:dio/dio.dart';

/// Injects the access token without logging sensitive headers.
/// Token refresh should replace this interceptor rather than nesting calls.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required SecureStorageService secureStorage})
    : _secureStorage = secureStorage;

  final SecureStorageService _secureStorage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _secureStorage.read(key: StorageKeys.accessToken);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
