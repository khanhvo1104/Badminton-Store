import 'package:base_project/app/app.dart';
import 'package:base_project/core/config/app_config.dart';
import 'package:base_project/core/config/app_environment.dart';
import 'package:base_project/core/config/demo_credentials.dart';
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
import 'package:base_project/features/home/data/data_sources/fake_home_remote_data_source.dart';
import 'package:base_project/features/home/di/home_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'successful authentication opens protected app and logout returns to login',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appEnvironmentProvider.overrideWithValue(
              AppEnvironment.development,
            ),
            appConfigProvider.overrideWithValue(
              const AppConfig(
                environment: AppEnvironment.development,
                apiBaseUrl: 'https://test.example.com',
                enableNetworkLogs: false,
                enableDebugTools: true,
              ),
            ),
            sharedPreferencesProvider.overrideWithValue(preferences),
            preferencesServiceProvider.overrideWithValue(
              FakePreferencesService(),
            ),
            secureStorageServiceProvider.overrideWithValue(
              FakeSecureStorageService(),
            ),
            networkInfoProvider.overrideWithValue(FakeNetworkInfo()),
            appLoggerProvider.overrideWithValue(AppLogger()),
            authRemoteDataSourceProvider.overrideWithValue(
              FakeAuthRemoteDataSource(delay: Duration.zero),
            ),
            homeRemoteDataSourceProvider.overrideWithValue(
              FakeHomeRemoteDataSource(delay: Duration.zero),
            ),
          ],
          child: const App(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sign in to continue'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        DemoCredentials.email,
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        DemoCredentials.password,
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_greeting')), findsOneWidget);
      expect(find.textContaining('Hello,'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('logout_button')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const Key('logout_button')));
      await tester.pumpAndSettle();

      expect(find.text('Sign in to continue'), findsOneWidget);
    },
  );
}
