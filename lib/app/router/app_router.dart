import 'package:base_project/app/router/app_routes.dart';
import 'package:base_project/app/router/route_refresh_notifier.dart';
import 'package:base_project/features/authentication/presentation/views/login_page.dart';
import 'package:base_project/features/authentication/presentation/views/splash_page.dart';
import 'package:base_project/features/design_system/presentation/views/design_system_gallery_page.dart';
import 'package:base_project/features/home/presentation/views/home_page.dart';
import 'package:base_project/features/profile/presentation/views/profile_page.dart';
import 'package:base_project/features/settings/presentation/views/settings_page.dart';
import 'package:base_project/shared/session/auth_session_provider.dart';
import 'package:base_project/shared/session/auth_session_state.dart';
import 'package:base_project/shared/widgets/app_scaffold.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routeRefreshNotifierProvider = Provider<RouteRefreshNotifier>((ref) {
  final notifier = RouteRefreshNotifier();
  ref
    ..listen<AuthSessionState>(authSessionProvider, (_, __) {
      notifier.refresh();
    })
    ..onDispose(notifier.dispose);
  return notifier;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(routeRefreshNotifierProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final session = ref.read(authSessionProvider);
      final location = state.matchedLocation;
      final isSplash = location == AppRoutes.splash;
      final isLoginRoute = location == AppRoutes.login;
      final isDesignSystem = location == AppRoutes.designSystem;

      if (session is AuthSessionInitial ||
          session is AuthSessionLoading ||
          session is AuthSessionError) {
        return isSplash ? null : AppRoutes.splash;
      }

      final isAuthenticated = session is AuthSessionAuthenticated;

      if (!isAuthenticated && !isLoginRoute) {
        return AppRoutes.login;
      }

      if (isDesignSystem && (!kDebugMode || !isAuthenticated)) {
        return AppRoutes.home;
      }

      if (isAuthenticated && (isLoginRoute || isSplash)) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: AppRoutes.splashName,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.loginName,
        builder: (context, state) => const LoginPage(),
      ),
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.designSystem,
          name: AppRoutes.designSystemName,
          builder: (context, state) => const DesignSystemGalleryPage(),
        ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: AppRoutes.homeName,
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                name: AppRoutes.profileName,
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                name: AppRoutes.settingsName,
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(title: const Text('Not found')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('No route for ${state.uri}'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Go home'),
              ),
            ],
          ),
        ),
      );
    },
  );
});
