import 'package:base_project/app/router/app_routes.dart';
import 'package:base_project/shared/session/auth_session_state.dart';

/// Pure GoRouter auth redirect decision.
///
/// Deterministic from [session] kind, [matchedLocation], and whether the
/// debug-only design-system route is registered. Does not touch Supabase or
/// expose session/user details.
String? resolveAuthRedirect({
  required AuthSessionState session,
  required String matchedLocation,
  required bool isDesignSystemRouteAvailable,
}) {
  final isSplash = matchedLocation == AppRoutes.splash;
  final isLoginRoute = matchedLocation == AppRoutes.login;
  final isDesignSystem = matchedLocation == AppRoutes.designSystem;
  final isRoot = matchedLocation == AppRoutes.root;

  if (session is AuthSessionInitial ||
      session is AuthSessionLoading ||
      session is AuthSessionError) {
    return isSplash ? null : AppRoutes.splash;
  }

  final isAuthenticated = session is AuthSessionAuthenticated;

  if (!isAuthenticated && !isLoginRoute) {
    return AppRoutes.login;
  }

  if (isDesignSystem && (!isDesignSystemRouteAvailable || !isAuthenticated)) {
    return AppRoutes.home;
  }

  if (isAuthenticated && (isLoginRoute || isSplash || isRoot)) {
    return AppRoutes.home;
  }

  return null;
}
