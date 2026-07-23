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

final class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause, super.stackTrace});
}

final class UnauthorizedException extends AppException {
  const UnauthorizedException(super.message, {super.cause, super.stackTrace});
}

final class ValidationException extends AppException {
  const ValidationException(
    super.message, {
    this.fieldErrors = const {},
    super.cause,
    super.stackTrace,
  });

  final Map<String, String> fieldErrors;
}

final class ServerException extends AppException {
  const ServerException(
    super.message, {
    this.statusCode,
    super.cause,
    super.stackTrace,
  });

  final int? statusCode;
}

final class CacheException extends AppException {
  const CacheException(super.message, {super.cause, super.stackTrace});
}

final class UnknownException extends AppException {
  const UnknownException(super.message, {super.cause, super.stackTrace});
}
