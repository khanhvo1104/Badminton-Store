import 'package:base_project/app/app.dart';
import 'package:base_project/app/router/app_router.dart';
import 'package:base_project/app/router/app_routes.dart';
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
import 'package:base_project/features/authentication/domain/entities/user.dart';
import 'package:base_project/features/home/data/data_sources/fake_home_remote_data_source.dart';
import 'package:base_project/features/home/di/home_providers.dart';
import 'package:base_project/shared/session/auth_session_provider.dart';
import 'package:base_project/shared/session/auth_session_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _user = User(
  id: 'user-1',
  email: 'demo@example.com',
  displayName: 'Demo User',
);

/// Keeps [authSessionProvider] on a fixed state without async restore races.
class _FixedAuthSessionNotifier extends AuthSessionNotifier {
  _FixedAuthSessionNotifier(this._fixed, Ref ref) : super(ref) {
    state = _fixed;
  }

  final AuthSessionState _fixed;

  @override
  Future<void> restoreSession() async {
    state = _fixed;
  }
}

Future<List<Override>> _baseOverrides({
  required AuthSessionState session,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();

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
    sharedPreferencesProvider.overrideWithValue(preferences),
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
    authSessionProvider.overrideWith(
      (ref) => _FixedAuthSessionNotifier(session, ref),
    ),
  ];
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  required AuthSessionState session,
  bool settle = true,
}) async {
  final overrides = await _baseOverrides(session: session);
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const App()),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // Loading splash uses an indeterminate progress indicator that never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
  return container;
}

Future<void> _pumpRouterFrame(WidgetTester tester, {bool settle = true}) async {
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
}

GoRouter _routerOf(ProviderContainer container) {
  return container.read(appRouterProvider);
}

void main() {
  testWidgets(
    'loading session keeps splash and redirects protected deep links',
    (tester) async {
      final container = await _pumpApp(
        tester,
        session: const AuthSessionLoading(),
        settle: false,
      );
      final router = _routerOf(container);

      expect(router.state.uri.path, AppRoutes.splash);
      expect(find.text('Starting...'), findsOneWidget);

      for (final location in [
        AppRoutes.home,
        AppRoutes.profile,
        AppRoutes.orders,
        AppRoutes.login,
      ]) {
        router.go(location);
        await _pumpRouterFrame(tester, settle: false);
        expect(router.state.uri.path, AppRoutes.splash, reason: location);
      }
    },
  );

  testWidgets('session error keeps splash and redirects other locations', (
    tester,
  ) async {
    final container = await _pumpApp(
      tester,
      session: const AuthSessionError('corrupt session'),
    );
    final router = _routerOf(container);

    expect(router.state.uri.path, AppRoutes.splash);
    expect(find.text('corrupt session'), findsOneWidget);

    router.go(AppRoutes.home);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.splash);
  });

  testWidgets('unauthenticated protected deep links redirect to login', (
    tester,
  ) async {
    final container = await _pumpApp(
      tester,
      session: const AuthSessionUnauthenticated(),
    );
    final router = _routerOf(container);

    expect(router.state.uri.path, AppRoutes.login);

    for (final location in [
      AppRoutes.home,
      AppRoutes.profile,
      AppRoutes.orders,
      AppRoutes.addresses,
      AppRoutes.settings,
      AppRoutes.checkout,
    ]) {
      router.go(location);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.login, reason: location);
      expect(find.byKey(const Key('login_email_field')), findsOneWidget);
    }
  });

  testWidgets('authenticated splash login and root redirect to home', (
    tester,
  ) async {
    final container = await _pumpApp(
      tester,
      session: const AuthSessionAuthenticated(_user),
    );
    final router = _routerOf(container);

    expect(router.state.uri.path, AppRoutes.home);
    expect(find.byKey(const Key('home_greeting')), findsOneWidget);

    for (final location in [
      AppRoutes.root,
      AppRoutes.splash,
      AppRoutes.login,
    ]) {
      router.go(location);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.home, reason: location);
    }
  });

  testWidgets(
    'authenticated settings stays put until logout refreshes to login',
    (tester) async {
      final container = await _pumpApp(
        tester,
        session: const AuthSessionAuthenticated(_user),
      );
      final router = _routerOf(container)..go(AppRoutes.settings);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.settings);
      expect(find.byKey(const Key('logout_button')), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('logout_button')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const Key('logout_button')));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.login);
      expect(find.byKey(const Key('login_email_field')), findsOneWidget);
      expect(find.byKey(const Key('logout_button')), findsNothing);
      expect(find.text('Settings'), findsNothing);
    },
  );

  testWidgets(
    'unknown route shows not-found UI with Go home for authenticated session',
    (tester) async {
      final container = await _pumpApp(
        tester,
        session: const AuthSessionAuthenticated(_user),
      );
      final router = _routerOf(container)..go('/definitely-not-a-route');
      await tester.pumpAndSettle();

      expect(find.text('Not found'), findsOneWidget);
      expect(find.textContaining('No route for'), findsOneWidget);
      expect(find.text('Go home'), findsOneWidget);

      await tester.tap(find.text('Go home'));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.home);
      expect(find.byKey(const Key('home_greeting')), findsOneWidget);
    },
  );
}
