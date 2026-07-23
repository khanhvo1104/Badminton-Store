import 'package:logger/logger.dart';

class AppLogger {
  AppLogger({bool enableDebugLogs = false})
    : _logger = Logger(
        printer: PrettyPrinter(
          methodCount: 0,
          errorMethodCount: 8,
          lineLength: 80,
          colors: false,
        ),
        level: enableDebugLogs ? Level.debug : Level.warning,
      );

  final Logger _logger;

  void debug(String message) => _logger.d(message);

  void info(String message) => _logger.i(message);

  void warning(String message) => _logger.w(message);

  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}
