/// Application-level exception hierarchy.
/// Infrastructure exceptions are mapped into these types before leaving
/// the data layer.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause, this.stackTrace});

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => 'AppException($message)';
}

/// Authentication / session failures (sign-in, token refresh, sign-out).
final class AuthenticationException extends AppException {
  const AuthenticationException(super.message, {super.cause, super.stackTrace});
}

/// Connectivity and transport-level failures.
final class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause, super.stackTrace});
}

/// Remote or local database / query failures (e.g. Supabase PostgREST).
final class DatabaseException extends AppException {
  const DatabaseException(
    super.message, {
    this.code,
    super.cause,
    super.stackTrace,
  });

  final String? code;
}

/// Session expired or caller lacks permission for the resource.
final class UnauthorizedException extends AppException {
  const UnauthorizedException(super.message, {super.cause, super.stackTrace});
}

/// Input or domain-rule validation failures.
final class ValidationException extends AppException {
  const ValidationException(
    super.message, {
    this.fieldErrors = const {},
    super.cause,
    super.stackTrace,
  });

  final Map<String, String> fieldErrors;
}

/// File / object storage failures (uploads, signed URLs, buckets).
final class StorageException extends AppException {
  const StorageException(super.message, {super.cause, super.stackTrace});
}

/// Unexpected or non-success HTTP / RPC responses from the backend.
final class ServerException extends AppException {
  const ServerException(
    super.message, {
    this.statusCode,
    super.cause,
    super.stackTrace,
  });

  final int? statusCode;
}

/// Local cache / preferences read-write failures.
final class CacheException extends AppException {
  const CacheException(super.message, {super.cause, super.stackTrace});
}

/// Fallback when an error cannot be classified.
final class UnknownException extends AppException {
  const UnknownException(super.message, {super.cause, super.stackTrace});
}
