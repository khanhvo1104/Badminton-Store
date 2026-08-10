import 'package:base_project/core/config/app_config.dart';
import 'package:base_project/core/config/app_environment.dart';
import 'package:base_project/core/config/environment_provider.dart';
import 'package:base_project/core/logging/app_logger.dart';
import 'package:base_project/core/logging/logger_provider.dart';
import 'package:base_project/core/network/network_info.dart';
import 'package:base_project/core/network/network_info_provider.dart';
import 'package:base_project/core/storage/preferences_service.dart';
import 'package:base_project/core/storage/secure_storage_service.dart';
import 'package:base_project/core/storage/storage_providers.dart';
import 'package:base_project/features/authentication/data/data_sources/fake_auth_remote_data_source.dart';
import 'package:base_project/features/authentication/di/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> createTestContainer({
  List<Override> overrides = const [],
  SecureStorageService? secureStorage,
  NetworkInfo? networkInfo,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();

  return ProviderContainer(
    overrides: [
      appEnvironmentProvider.overrideWithValue(AppEnvironment.development),
      appConfigProvider.overrideWithValue(
        const AppConfig(
          environment: AppEnvironment.development,
          apiBaseUrl: 'https://test.example.com',
          enableNetworkLogs: false,
          enableDebugTools: false,
        ),
      ),
      sharedPreferencesProvider.overrideWithValue(preferences),
      preferencesServiceProvider.overrideWithValue(FakePreferencesService()),
      secureStorageServiceProvider.overrideWithValue(
        secureStorage ?? FakeSecureStorageService(),
      ),
      networkInfoProvider.overrideWithValue(networkInfo ?? FakeNetworkInfo()),
      appLoggerProvider.overrideWithValue(AppLogger()),
      authRemoteDataSourceProvider.overrideWithValue(
        FakeAuthRemoteDataSource(delay: Duration.zero),
      ),
      ...overrides,
    ],
  );
}
