import 'package:base_project/core/config/app_config.dart';
import 'package:base_project/core/config/app_environment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appEnvironmentProvider = Provider<AppEnvironment>((ref) {
  throw UnimplementedError(
    'appEnvironmentProvider must be overridden in bootstrap',
  );
});

final appConfigProvider = Provider<AppConfig>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  return AppConfig.fromEnvironment(environment);
});
