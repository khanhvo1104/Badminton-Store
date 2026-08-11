import 'package:base_project/app/router/app_routes.dart';
import 'package:base_project/app/router/auth_redirect_policy.dart';
import 'package:base_project/app/router/route_refresh_notifier.dart';
import 'package:base_project/features/addresses/presentation/views/addresses_page.dart';
import 'package:base_project/features/authentication/presentation/views/login_page.dart';
import 'package:base_project/features/authentication/presentation/views/splash_page.dart';
import 'package:base_project/features/cart/presentation/views/cart_page.dart';
import 'package:base_project/features/catalog/presentation/views/catalog_page.dart';
import 'package:base_project/features/checkout/presentation/views/checkout_page.dart';
import 'package:base_project/features/design_system/presentation/views/design_system_gallery_page.dart';
import 'package:base_project/features/favorites/presentation/views/favorites_page.dart';
import 'package:base_project/features/home/presentation/views/home_page.dart';
import 'package:base_project/features/notifications/presentation/views/notifications_page.dart';
import 'package:base_project/features/orders/presentation/views/orders_page.dart';
import 'package:base_project/features/product/presentation/views/product_detail_page.dart';
import 'package:base_project/features/profile/presentation/views/profile_page.dart';
import 'package:base_project/features/search/presentation/views/search_page.dart';
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
      return resolveAuthRedirect(
        session: ref.read(authSessionProvider),
        matchedLocation: state.matchedLocation,
        isDesignSystemRouteAvailable: kDebugMode,
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.root,
        name: AppRoutes.rootName,
        redirect: (_, __) => AppRoutes.home,
      ),
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
      GoRoute(
        path: AppRoutes.product,
        name: AppRoutes.productName,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ProductDetailPage(productId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.checkout,
        name: AppRoutes.checkoutName,
        builder: (context, state) => const CheckoutPage(),
      ),
      GoRoute(
        path: AppRoutes.orders,
        name: AppRoutes.ordersName,
        builder: (context, state) => const OrdersPage(),
      ),
      GoRoute(
        path: AppRoutes.addresses,
        name: AppRoutes.addressesName,
        builder: (context, state) => const AddressesPage(),
      ),
      GoRoute(
        path: AppRoutes.search,
        name: AppRoutes.searchName,
        builder: (context, state) => const SearchPage(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: AppRoutes.settingsName,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        name: AppRoutes.notificationsName,
        builder: (context, state) => const NotificationsPage(),
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
                path: AppRoutes.catalog,
                name: AppRoutes.catalogName,
                builder: (context, state) => const CatalogPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.cart,
                name: AppRoutes.cartName,
                builder: (context, state) => const CartPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.favorites,
                name: AppRoutes.favoritesName,
                builder: (context, state) => const FavoritesPage(),
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
