import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/logging/app_logger.dart';
import 'package:dio/dio.dart';

/// Converts infrastructure exceptions into [AppException] values.
class ErrorMapper {
  const ErrorMapper(this._logger);

  final AppLogger _logger;

  AppException map(Object error, [StackTrace? stackTrace]) {
    if (error is AppException) {
      return error;
    }

    if (error is DioException) {
      return _mapDioException(error, stackTrace);
    }

    _logger.error('Unexpected exception', error: error, stackTrace: stackTrace);

    return UnknownException(
      'An unexpected error occurred',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  AppException _mapDioException(DioException error, StackTrace? stackTrace) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return NetworkException(
          'Unable to reach the server. Check your connection.',
          cause: error,
          stackTrace: stackTrace ?? error.stackTrace,
        );
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401) {
          return UnauthorizedException(
            'Session expired. Please sign in again.',
            cause: error,
            stackTrace: stackTrace ?? error.stackTrace,
          );
        }
        if (statusCode == 403) {
          return UnauthorizedException(
            'You do not have permission to perform this action.',
            cause: error,
            stackTrace: stackTrace ?? error.stackTrace,
          );
        }
        return ServerException(
          'Server error (${statusCode ?? 'unknown'})',
          statusCode: statusCode,
          cause: error,
          stackTrace: stackTrace ?? error.stackTrace,
        );
      case DioExceptionType.cancel:
        return const NetworkException('Request was cancelled');
      case DioExceptionType.badCertificate:
        return NetworkException(
          'Secure connection could not be verified.',
          cause: error,
          stackTrace: stackTrace ?? error.stackTrace,
        );
      case DioExceptionType.unknown:
      case DioExceptionType.transformTimeout:
        return NetworkException(
          'Network request failed',
          cause: error,
          stackTrace: stackTrace ?? error.stackTrace,
        );
    }
  }
}
