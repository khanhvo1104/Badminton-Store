import 'package:base_project/core/config/environment_provider.dart';
import 'package:base_project/core/logging/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appLoggerProvider = Provider<AppLogger>((ref) {
  final config = ref.watch(appConfigProvider);
  return AppLogger(enableDebugLogs: config.enableDebugTools);
});
