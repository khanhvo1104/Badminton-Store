import 'package:base_project/app/router/app_routes.dart';
import 'package:base_project/app/router/auth_redirect_policy.dart';
import 'package:base_project/features/authentication/domain/entities/user.dart';
import 'package:base_project/shared/session/auth_session_state.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = User(
  id: 'user-1',
  email: 'demo@example.com',
  displayName: 'Demo User',
);

void main() {
  const protectedLocations = <String>[
    AppRoutes.home,
    AppRoutes.profile,
    AppRoutes.orders,
    AppRoutes.addresses,
    AppRoutes.settings,
    AppRoutes.checkout,
    AppRoutes.catalog,
    AppRoutes.cart,
    AppRoutes.favorites,
    AppRoutes.search,
    AppRoutes.notifications,
  ];

  group('fail-closed splash for unresolved session', () {
    for (final session in <AuthSessionState>[
      const AuthSessionInitial(),
      const AuthSessionLoading(),
      const AuthSessionError('restore failed'),
    ]) {
      test('$session keeps splash and redirects other locations', () {
        expect(
          resolveAuthRedirect(
            session: session,
            matchedLocation: AppRoutes.splash,
            isDesignSystemRouteAvailable: true,
          ),
          isNull,
        );

        for (final location in [
          AppRoutes.root,
          AppRoutes.login,
          ...protectedLocations,
          AppRoutes.designSystem,
          '/unknown',
        ]) {
          expect(
            resolveAuthRedirect(
              session: session,
              matchedLocation: location,
              isDesignSystemRouteAvailable: true,
            ),
            AppRoutes.splash,
            reason: '$session at $location',
          );
        }
      });
    }
  });

  group('unauthenticated', () {
    const session = AuthSessionUnauthenticated();

    test('may remain on login', () {
      expect(
        resolveAuthRedirect(
          session: session,
          matchedLocation: AppRoutes.login,
          isDesignSystemRouteAvailable: true,
        ),
        isNull,
      );
    });

    test('protected deep links redirect to login', () {
      for (final location in protectedLocations) {
        expect(
          resolveAuthRedirect(
            session: session,
            matchedLocation: location,
            isDesignSystemRouteAvailable: true,
          ),
          AppRoutes.login,
          reason: location,
        );
      }
    });

    test('splash and root redirect to login', () {
      expect(
        resolveAuthRedirect(
          session: session,
          matchedLocation: AppRoutes.splash,
          isDesignSystemRouteAvailable: true,
        ),
        AppRoutes.login,
      );
      expect(
        resolveAuthRedirect(
          session: session,
          matchedLocation: AppRoutes.root,
          isDesignSystemRouteAvailable: true,
        ),
        AppRoutes.login,
      );
    });
  });

  group('authenticated', () {
    const session = AuthSessionAuthenticated(_user);

    test('root, splash, and login redirect to home', () {
      for (final location in [
        AppRoutes.root,
        AppRoutes.splash,
        AppRoutes.login,
      ]) {
        expect(
          resolveAuthRedirect(
            session: session,
            matchedLocation: location,
            isDesignSystemRouteAvailable: true,
          ),
          AppRoutes.home,
          reason: location,
        );
      }
    });

    test('protected and account destinations remain unchanged', () {
      for (final location in protectedLocations) {
        expect(
          resolveAuthRedirect(
            session: session,
            matchedLocation: location,
            isDesignSystemRouteAvailable: true,
          ),
          isNull,
          reason: location,
        );
      }
    });
  });

  group('design-system route', () {
    const authenticated = AuthSessionAuthenticated(_user);
    const unauthenticated = AuthSessionUnauthenticated();

    test('debug + authenticated allows design-system', () {
      expect(
        resolveAuthRedirect(
          session: authenticated,
          matchedLocation: AppRoutes.designSystem,
          isDesignSystemRouteAvailable: true,
        ),
        isNull,
      );
    });

    test('release fallback sends design-system to home when authenticated', () {
      expect(
        resolveAuthRedirect(
          session: authenticated,
          matchedLocation: AppRoutes.designSystem,
          isDesignSystemRouteAvailable: false,
        ),
        AppRoutes.home,
      );
    });

    test('unauthenticated design-system still redirects to login first', () {
      expect(
        resolveAuthRedirect(
          session: unauthenticated,
          matchedLocation: AppRoutes.designSystem,
          isDesignSystemRouteAvailable: true,
        ),
        AppRoutes.login,
      );
      expect(
        resolveAuthRedirect(
          session: unauthenticated,
          matchedLocation: AppRoutes.designSystem,
          isDesignSystemRouteAvailable: false,
        ),
        AppRoutes.login,
      );
    });
  });
}
