abstract final class ApiConstants {
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 15);

  static const String contentType = 'application/json';
  static const String accept = 'application/json';
}
