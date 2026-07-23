import 'package:base_project/app/theme/app_theme.dart';
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
import 'package:base_project/features/authentication/presentation/views/login_page.dart';
import 'package:base_project/features/home/data/data_sources/fake_home_remote_data_source.dart';
import 'package:base_project/features/home/di/home_providers.dart';
import 'package:base_project/features/home/presentation/views/home_page.dart';
import 'package:base_project/features/settings/presentation/views/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Override> _baseOverrides() {
  return [
    appEnvironmentProvider.overrideWithValue(AppEnvironment.development),
    appConfigProvider.overrideWithValue(
      const AppConfig(
        environment: AppEnvironment.development,
        apiBaseUrl: 'https://test.example.com',
        enableNetworkLogs: false,
        enableDebugTools: true,
      ),
    ),
    preferencesServiceProvider.overrideWithValue(FakePreferencesService()),
    secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
    networkInfoProvider.overrideWithValue(FakeNetworkInfo()),
    appLoggerProvider.overrideWithValue(AppLogger()),
    authRemoteDataSourceProvider.overrideWithValue(
      FakeAuthRemoteDataSource(delay: Duration.zero),
    ),
    homeRemoteDataSourceProvider.overrideWithValue(
      FakeHomeRemoteDataSource(delay: Duration.zero),
    ),
  ];
}

Widget _app(Widget home) {
  return MaterialApp(theme: AppTheme.light(), home: home);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('login validation is displayed', (tester) async {
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._baseOverrides(),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: _app(const LoginPage()),
      ),
    );

    await tester.enterText(find.byKey(const Key('login_email_field')), 'bad');
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'short',
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
  });

  testWidgets('demo credentials are shown when debug tools enabled', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._baseOverrides(),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: _app(const LoginPage()),
      ),
    );

    expect(find.text('Demo account'), findsOneWidget);
    expect(find.textContaining(DemoCredentials.email), findsOneWidget);
  });

  testWidgets('loading disables the login button', (tester) async {
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._baseOverrides(),
          sharedPreferencesProvider.overrideWithValue(preferences),
          authRemoteDataSourceProvider.overrideWithValue(
            FakeAuthRemoteDataSource(delay: const Duration(milliseconds: 300)),
          ),
        ],
        child: _app(const LoginPage()),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('login_email_field')),
      DemoCredentials.email,
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      DemoCredentials.password,
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  });

  testWidgets('home renders dashboard data', (tester) async {
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._baseOverrides(),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: _app(const HomePage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Active sessions'), findsOneWidget);
    expect(find.text('Security score'), findsOneWidget);
  });

  testWidgets('error state renders retry action', (tester) async {
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._baseOverrides(),
          sharedPreferencesProvider.overrideWithValue(preferences),
          homeRemoteDataSourceProvider.overrideWithValue(
            FakeHomeRemoteDataSource(delay: Duration.zero, shouldFail: true),
          ),
        ],
        child: _app(const HomePage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('logout button is present on settings', (tester) async {
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._baseOverrides(),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: _app(const SettingsPage()),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('logout_button')),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.byKey(const Key('logout_button')), findsOneWidget);
  });
}
