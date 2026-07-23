import 'package:base_project/core/config/environment_provider.dart';
import 'package:base_project/core/constants/api_constants.dart';
import 'package:base_project/core/logging/logger_provider.dart';
import 'package:base_project/core/network/auth_interceptor.dart';
import 'package:base_project/core/storage/storage_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Configured Dio client for future real remote data sources.
final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final logger = ref.watch(appLoggerProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      sendTimeout: ApiConstants.sendTimeout,
      headers: {
        Headers.contentTypeHeader: ApiConstants.contentType,
        Headers.acceptHeader: ApiConstants.accept,
      },
    ),
  );

  dio.interceptors.add(AuthInterceptor(secureStorage: secureStorage));

  if (config.enableNetworkLogs) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: true,
        requestHeader: false,
        responseHeader: false,
        logPrint: (object) {
          final message = object.toString();
          if (_containsSensitiveData(message)) {
            logger.debug('[HTTP] <redacted>');
            return;
          }
          logger.debug('[HTTP] $message');
        },
      ),
    );
  }

  return dio;
});

bool _containsSensitiveData(String message) {
  final lower = message.toLowerCase();
  return lower.contains('authorization') ||
      lower.contains('password') ||
      lower.contains('access_token') ||
      lower.contains('"token"') ||
      lower.contains('bearer ');
}
