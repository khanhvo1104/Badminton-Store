import 'dart:async';

import 'package:base_project/app/router/app_routes.dart';
import 'package:base_project/app/theme/app_theme.dart';
import 'package:base_project/core/config/app_config.dart';
import 'package:base_project/core/config/app_environment.dart';
import 'package:base_project/core/config/environment_provider.dart';
import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/logging/app_logger.dart';
import 'package:base_project/core/logging/logger_provider.dart';
import 'package:base_project/core/network/network_info.dart';
import 'package:base_project/core/network/network_info_provider.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/core/storage/preferences_service.dart';
import 'package:base_project/core/storage/secure_storage_service.dart';
import 'package:base_project/core/storage/storage_providers.dart';
import 'package:base_project/features/authentication/data/data_sources/fake_auth_remote_data_source.dart';
import 'package:base_project/features/authentication/di/auth_providers.dart';
import 'package:base_project/features/authentication/domain/entities/user.dart';
import 'package:base_project/features/profile/di/profile_providers.dart';
import 'package:base_project/features/profile/domain/repositories/profile_repository.dart';
import 'package:base_project/features/profile/domain/use_cases/update_profile_use_case.dart';
import 'package:base_project/features/profile/presentation/views/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

const _user = User(
  id: 'user-1',
  email: 'demo@example.com',
  displayName: 'Demo User',
);

void main() {
  late _MockProfileRepository repository;
  late GoRouter router;

  setUp(() {
    repository = _MockProfileRepository();
  });

  Future<List<Override>> overrides() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    return [
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
        FakeSecureStorageService(),
      ),
      networkInfoProvider.overrideWithValue(FakeNetworkInfo()),
      appLoggerProvider.overrideWithValue(AppLogger()),
      authRemoteDataSourceProvider.overrideWithValue(
        FakeAuthRemoteDataSource(delay: Duration.zero),
      ),
      profileRepositoryProvider.overrideWithValue(repository),
      updateProfileUseCaseProvider.overrideWithValue(
        UpdateProfileUseCase(repository),
      ),
    ];
  }

  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: AppRoutes.profile,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return Scaffold(
              body: navigationShell,
              bottomNavigationBar: NavigationBar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: navigationShell.goBranch,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    label: 'Profile',
                  ),
                ],
              ),
            );
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.home,
                  builder: (_, __) =>
                      const Scaffold(body: Text('home-shell-page')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.profile,
                  builder: (_, __) => const ProfilePage(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.orders,
          builder: (_, __) => const Scaffold(body: Text('orders-page')),
        ),
        GoRoute(
          path: AppRoutes.addresses,
          builder: (_, __) => const Scaffold(body: Text('addresses-page')),
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (_, __) => const Scaffold(body: Text('settings-page')),
        ),
      ],
    );
  }

  Future<void> pumpProfile(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    router = buildRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: await overrides(),
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
  }

  Future<void> settleLoadedProfile(WidgetTester tester) async {
    await pumpProfile(tester);
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsOneWidget);
  }

  String displayNameText(WidgetTester tester) {
    return tester
        .widget<TextFormField>(
          find.descendant(
            of: find.byKey(const Key('profile_display_name_field')),
            matching: find.byType(TextFormField),
          ),
        )
        .controller!
        .text;
  }

  group('account navigation hub', () {
    setUp(() {
      when(
        () => repository.getProfile(),
      ).thenAnswer((_) async => const Success(_user));
    });

    testWidgets('Orders tap reaches AppRoutes.orders', (tester) async {
      await settleLoadedProfile(tester);

      await tester.tap(find.byKey(const Key('profile_account_orders')));
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), AppRoutes.orders);
      expect(find.text('orders-page'), findsOneWidget);
    });

    testWidgets('Addresses tap reaches AppRoutes.addresses', (tester) async {
      await settleLoadedProfile(tester);

      await tester.tap(find.byKey(const Key('profile_account_addresses')));
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), AppRoutes.addresses);
      expect(find.text('addresses-page'), findsOneWidget);
    });

    testWidgets('Settings & logout tap reaches AppRoutes.settings', (
      tester,
    ) async {
      await settleLoadedProfile(tester);

      await tester.tap(find.byKey(const Key('profile_account_settings')));
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), AppRoutes.settings);
      expect(find.text('settings-page'), findsOneWidget);
    });

    testWidgets(
      'back from each destination restores Profile shell and unsaved draft',
      (tester) async {
        await settleLoadedProfile(tester);

        const draft = 'Unsaved Draft Name';
        await tester.enterText(
          find.byKey(const Key('profile_display_name_field')),
          draft,
        );
        await tester.pump();

        final destinations = <(Key, String, String)>[
          (
            const Key('profile_account_orders'),
            AppRoutes.orders,
            'orders-page',
          ),
          (
            const Key('profile_account_addresses'),
            AppRoutes.addresses,
            'addresses-page',
          ),
          (
            const Key('profile_account_settings'),
            AppRoutes.settings,
            'settings-page',
          ),
        ];

        for (final (key, route, pageLabel) in destinations) {
          await tester.ensureVisible(find.byKey(key));
          await tester.tap(find.byKey(key));
          await tester.pumpAndSettle();

          expect(router.state.uri.toString(), route);
          expect(find.text(pageLabel), findsOneWidget);

          router.pop();
          await tester.pumpAndSettle();

          expect(router.state.uri.toString(), AppRoutes.profile);
          expect(find.text('Account'), findsOneWidget);
          expect(find.byType(NavigationBar), findsOneWidget);
          expect(displayNameText(tester), draft);
        }
      },
    );

    testWidgets(
      'account entries stay usable while save is pending and do not reset draft',
      (tester) async {
        final updateCompleter = Completer<Result<User>>();
        when(
          () => repository.updateDisplayName(any()),
        ).thenAnswer((_) => updateCompleter.future);

        await settleLoadedProfile(tester);

        const draft = 'Saving Draft';
        await tester.enterText(
          find.byKey(const Key('profile_display_name_field')),
          draft,
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('profile_save_button')));
        await tester.pump();

        expect(find.byKey(const Key('profile_account_orders')), findsOneWidget);

        await tester.ensureVisible(
          find.byKey(const Key('profile_account_orders')),
        );
        await tester.tap(find.byKey(const Key('profile_account_orders')));
        // Avoid pumpAndSettle while the save spinner is still animating under
        // the stateful shell IndexedStack.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(router.state.uri.toString(), AppRoutes.orders);
        expect(find.text('orders-page'), findsOneWidget);

        router.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(router.state.uri.toString(), AppRoutes.profile);
        expect(displayNameText(tester), draft);

        updateCompleter.complete(
          const Success(
            User(id: 'user-1', email: 'demo@example.com', displayName: draft),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Profile updated'), findsOneWidget);
        expect(displayNameText(tester), draft);
        verify(() => repository.updateDisplayName(draft)).called(1);
      },
    );

    testWidgets('does not expose a notifications link', (tester) async {
      await settleLoadedProfile(tester);

      expect(find.textContaining('Notification'), findsNothing);
      expect(
        find.byKey(const Key('profile_account_notifications')),
        findsNothing,
      );
    });
  });

  group('loading and error states', () {
    testWidgets('loading state hides account links', (tester) async {
      final profileCompleter = Completer<Result<User>>();
      when(
        () => repository.getProfile(),
      ).thenAnswer((_) => profileCompleter.future);

      await pumpProfile(tester);
      await tester.pump();

      expect(find.text('Loading profile...'), findsOneWidget);
      expect(find.text('Account'), findsNothing);
      expect(find.byKey(const Key('profile_account_orders')), findsNothing);
      expect(find.byKey(const Key('profile_account_addresses')), findsNothing);
      expect(find.byKey(const Key('profile_account_settings')), findsNothing);

      profileCompleter.complete(const Success(_user));
      await tester.pumpAndSettle();
    });

    testWidgets('error state hides account links', (tester) async {
      when(() => repository.getProfile()).thenAnswer(
        (_) async => const Failure(UnknownException('Failed to load')),
      );

      await pumpProfile(tester);
      await tester.pumpAndSettle();

      expect(find.text('Failed to load'), findsOneWidget);
      expect(find.text('Account'), findsNothing);
      expect(find.byKey(const Key('profile_account_orders')), findsNothing);
      expect(find.byKey(const Key('profile_account_addresses')), findsNothing);
      expect(find.byKey(const Key('profile_account_settings')), findsNothing);
    });
  });
}
