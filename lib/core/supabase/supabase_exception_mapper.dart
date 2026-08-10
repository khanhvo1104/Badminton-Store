import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/logging/app_logger.dart';

/// Maps Supabase / PostgREST / Auth / Storage failures into [AppException].
///
/// Shop Foundation provides the mapping surface only. Concrete SDK error
/// types will be handled when the Supabase client is wired.
class SupabaseExceptionMapper {
  const SupabaseExceptionMapper(this._logger);

  final AppLogger _logger;

  /// Converts an infrastructure [error] into a typed [AppException].
  AppException map(Object error, [StackTrace? stackTrace]) {
    if (error is AppException) {
      return error;
    }

    _logger.error(
      'Unmapped Supabase error',
      error: error,
      stackTrace: stackTrace,
    );

    return UnknownException(
      'An unexpected backend error occurred',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  /// Maps Auth-specific failures (invalid credentials, expired session).
  AppException mapAuth(Object error, [StackTrace? stackTrace]) {
    if (error is AppException) {
      return error;
    }

    return AuthenticationException(
      'Authentication failed',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  /// Maps database / PostgREST failures.
  AppException mapDatabase(Object error, [StackTrace? stackTrace]) {
    if (error is AppException) {
      return error;
    }

    return DatabaseException(
      'Database request failed',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  /// Maps storage bucket failures.
  AppException mapStorage(Object error, [StackTrace? stackTrace]) {
    if (error is AppException) {
      return error;
    }

    return StorageException(
      'Storage request failed',
      cause: error,
      stackTrace: stackTrace,
    );
  }
}
