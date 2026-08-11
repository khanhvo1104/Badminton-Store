import 'package:base_project/app/theme/app_theme.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/core/ui/glass/glass_background.dart';
import 'package:base_project/core/ui/glass/glass_theme_data.dart';
import 'package:base_project/features/addresses/di/addresses_providers.dart';
import 'package:base_project/features/addresses/domain/entities/address.dart';
import 'package:base_project/features/addresses/domain/repositories/address_repository.dart';
import 'package:base_project/features/addresses/presentation/views/addresses_page.dart';
import 'package:base_project/features/authentication/domain/entities/user.dart';
import 'package:base_project/features/cart/di/cart_providers.dart';
import 'package:base_project/features/cart/domain/entities/cart.dart';
import 'package:base_project/features/cart/domain/repositories/cart_repository.dart';
import 'package:base_project/features/cart/presentation/views/cart_page.dart';
import 'package:base_project/features/catalog/di/catalog_providers.dart';
import 'package:base_project/features/catalog/domain/entities/category.dart';
import 'package:base_project/features/catalog/domain/repositories/category_repository.dart';
import 'package:base_project/features/catalog/presentation/views/catalog_page.dart';
import 'package:base_project/features/favorites/di/favorites_providers.dart';
import 'package:base_project/features/favorites/domain/entities/favorite.dart';
import 'package:base_project/features/favorites/domain/repositories/favorite_repository.dart';
import 'package:base_project/features/favorites/presentation/views/favorites_page.dart';
import 'package:base_project/features/notifications/di/notifications_providers.dart';
import 'package:base_project/features/notifications/domain/entities/notification.dart';
import 'package:base_project/features/notifications/domain/repositories/notification_repository.dart';
import 'package:base_project/features/notifications/presentation/views/notifications_page.dart';
import 'package:base_project/features/orders/di/orders_providers.dart';
import 'package:base_project/features/orders/domain/entities/order.dart';
import 'package:base_project/features/orders/domain/repositories/order_repository.dart';
import 'package:base_project/features/orders/presentation/views/orders_page.dart';
import 'package:base_project/features/product/di/product_providers.dart';
import 'package:base_project/features/product/domain/entities/product.dart';
import 'package:base_project/features/product/domain/entities/product_variant.dart';
import 'package:base_project/features/product/domain/repositories/product_repository.dart';
import 'package:base_project/features/product/presentation/views/product_detail_page.dart';
import 'package:base_project/features/profile/di/profile_providers.dart';
import 'package:base_project/features/profile/domain/repositories/profile_repository.dart';
import 'package:base_project/features/profile/presentation/views/profile_page.dart';
import 'package:base_project/features/search/di/search_providers.dart';
import 'package:base_project/features/search/domain/repositories/search_repository.dart';
import 'package:base_project/features/search/presentation/views/search_page.dart';
import 'package:base_project/shared/widgets/shop_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockProductRepository extends Mock implements ProductRepository {}

class _MockCategoryRepository extends Mock implements CategoryRepository {}

class _MockCartRepository extends Mock implements CartRepository {}

class _MockFavoriteRepository extends Mock implements FavoriteRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockOrderRepository extends Mock implements OrderRepository {}

class _MockAddressRepository extends Mock implements AddressRepository {}

class _MockSearchRepository extends Mock implements SearchRepository {}

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

const _user = User(
  id: 'user-1',
  email: 'demo@example.com',
  displayName: 'Demo User',
);

const _product = Product(
  id: 'prod-1',
  name: 'Yonex Astrox 99',
  slug: 'yonex-astrox-99',
  categoryId: 'cat-1',
  status: 'active',
  shortDescription: 'Offensive racket',
  variants: [
    ProductVariant(
      id: 'var-1',
      productId: 'prod-1',
      sku: 'YX-99',
      price: 4500000,
      isDefault: true,
      availableQuantity: 8,
    ),
  ],
);

double _contrastRatio(Color a, Color b) {
  final luminances = [a.computeLuminance(), b.computeLuminance()]..sort();
  return (luminances[1] + 0.05) / (luminances[0] + 0.05);
}

Color _resolveSurface(WidgetTester tester, Finder anchor) {
  final context = tester.element(anchor);
  final theme = Theme.of(context);
  final scaffold = context.findAncestorWidgetOfExactType<Scaffold>();
  expect(scaffold, isNotNull);

  final scaffoldBg = scaffold!.backgroundColor ?? theme.scaffoldBackgroundColor;
  if (scaffoldBg.a > 0.01) {
    return scaffoldBg;
  }

  expect(
    find.ancestor(of: anchor, matching: find.byType(GlassBackground)),
    findsWidgets,
    reason: 'transparent scaffolds must sit on GlassBackground',
  );

  final glass = theme.extension<GlassThemeData>()!;
  final gradient = glass.backgroundGradient;
  expect(gradient, isA<LinearGradient>());
  final colors = (gradient as LinearGradient).colors;
  for (final color in colors) {
    expect(
      color.computeLuminance(),
      greaterThan(0.2),
      reason: 'glass background stops must stay light',
    );
  }
  return colors.first;
}

void _expectReadableLightScreen(WidgetTester tester, Finder title) {
  expect(title, findsOneWidget);
  final context = tester.element(title);
  final theme = Theme.of(context);
  final surface = _resolveSurface(tester, title);

  expect(theme.brightness, Brightness.light);
  expect(surface, isNot(const Color(0xFF000000)));
  expect(surface.computeLuminance(), greaterThan(0.2));
  expect(
    _contrastRatio(theme.colorScheme.onSurface, surface),
    greaterThanOrEqualTo(4.5),
  );
}

Future<void> _pumpChild({
  required WidgetTester tester,
  required Widget home,
  required List<Override> overrides,
  bool wrapGlass = false,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        home: wrapGlass ? GlassBackground(child: home) : home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late _MockProductRepository productRepository;
  late _MockCategoryRepository categoryRepository;
  late _MockCartRepository cartRepository;
  late _MockFavoriteRepository favoriteRepository;
  late _MockProfileRepository profileRepository;
  late _MockOrderRepository orderRepository;
  late _MockAddressRepository addressRepository;
  late _MockSearchRepository searchRepository;
  late _MockNotificationRepository notificationRepository;

  setUp(() {
    productRepository = _MockProductRepository();
    categoryRepository = _MockCategoryRepository();
    cartRepository = _MockCartRepository();
    favoriteRepository = _MockFavoriteRepository();
    profileRepository = _MockProfileRepository();
    orderRepository = _MockOrderRepository();
    addressRepository = _MockAddressRepository();
    searchRepository = _MockSearchRepository();
    notificationRepository = _MockNotificationRepository();
  });

  testWidgets(
    'product detail uses ShopPageScaffold light glass under ThemeMode.dark',
    (tester) async {
      when(
        () => productRepository.getById('prod-1'),
      ).thenAnswer((_) async => const Success(_product));
      when(
        () => favoriteRepository.contains('prod-1'),
      ).thenAnswer((_) async => const Success(false));

      await _pumpChild(
        tester: tester,
        overrides: [
          productRepositoryProvider.overrideWithValue(productRepository),
          favoriteRepositoryProvider.overrideWithValue(favoriteRepository),
        ],
        home: const ProductDetailPage(productId: 'prod-1'),
        themeMode: ThemeMode.dark,
      );

      expect(find.byType(ShopPageScaffold), findsOneWidget);
      _expectReadableLightScreen(tester, find.text('Product'));
      expect(find.text('Yonex Astrox 99'), findsOneWidget);
    },
  );

  testWidgets('catalog keeps light glass surface and readable chrome', (
    tester,
  ) async {
    when(
      () => categoryRepository.list(),
    ).thenAnswer((_) async => const Success(<Category>[]));
    when(
      () => productRepository.list(
        categoryId: any(named: 'categoryId'),
        brandId: any(named: 'brandId'),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => const Success(<Product>[]));

    await _pumpChild(
      tester: tester,
      wrapGlass: true,
      overrides: [
        categoryRepositoryProvider.overrideWithValue(categoryRepository),
        productRepositoryProvider.overrideWithValue(productRepository),
      ],
      home: const CatalogPage(),
      themeMode: ThemeMode.dark,
    );

    _expectReadableLightScreen(tester, find.text('Catalog'));
  });

  testWidgets('cart empty state stays light and readable', (tester) async {
    when(() => cartRepository.getCart()).thenAnswer(
      (_) async => const Success(
        Cart(id: 'cart-1', currencyCode: 'VND', status: 'active'),
      ),
    );

    await _pumpChild(
      tester: tester,
      wrapGlass: true,
      overrides: [cartRepositoryProvider.overrideWithValue(cartRepository)],
      home: const CartPage(),
      themeMode: ThemeMode.dark,
    );

    _expectReadableLightScreen(tester, find.text('Cart'));
    expect(find.text('Giỏ hàng đang trống'), findsOneWidget);
  });

  testWidgets('favorites empty state stays light and readable', (tester) async {
    when(
      () => favoriteRepository.list(),
    ).thenAnswer((_) async => const Success(<Favorite>[]));

    await _pumpChild(
      tester: tester,
      wrapGlass: true,
      overrides: [
        favoriteRepositoryProvider.overrideWithValue(favoriteRepository),
        productRepositoryProvider.overrideWithValue(productRepository),
      ],
      home: const FavoritesPage(),
      themeMode: ThemeMode.dark,
    );

    _expectReadableLightScreen(tester, find.text('Favorites'));
  });

  testWidgets('profile keeps light glass surface and readable title', (
    tester,
  ) async {
    when(
      () => profileRepository.getProfile(),
    ).thenAnswer((_) async => const Success(_user));
    when(
      () => notificationRepository.unreadCount(),
    ).thenAnswer((_) async => const Success(0));

    await _pumpChild(
      tester: tester,
      wrapGlass: true,
      overrides: [
        profileRepositoryProvider.overrideWithValue(profileRepository),
        notificationRepositoryProvider.overrideWithValue(
          notificationRepository,
        ),
      ],
      home: const ProfilePage(),
      themeMode: ThemeMode.dark,
    );

    _expectReadableLightScreen(tester, find.text('Profile'));
  });

  testWidgets('orders empty state uses light ShopPageScaffold', (tester) async {
    when(
      () => orderRepository.list(
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => const Success(<Order>[]));

    await _pumpChild(
      tester: tester,
      overrides: [orderRepositoryProvider.overrideWithValue(orderRepository)],
      home: const OrdersPage(),
      themeMode: ThemeMode.dark,
    );

    expect(find.byType(ShopPageScaffold), findsOneWidget);
    _expectReadableLightScreen(tester, find.text('Orders'));
    expect(find.text('Chưa có đơn hàng nào'), findsOneWidget);
  });

  testWidgets('addresses empty state uses light ShopPageScaffold', (
    tester,
  ) async {
    when(
      () => addressRepository.list(),
    ).thenAnswer((_) async => const Success(<Address>[]));

    await _pumpChild(
      tester: tester,
      overrides: [
        addressRepositoryProvider.overrideWithValue(addressRepository),
      ],
      home: const AddressesPage(),
      themeMode: ThemeMode.dark,
    );

    expect(find.byType(ShopPageScaffold), findsOneWidget);
    _expectReadableLightScreen(tester, find.text('Addresses'));
  });

  testWidgets('search stays light with readable primary text', (tester) async {
    when(
      () => searchRepository.recentQueries(),
    ).thenAnswer((_) async => const Success(<String>[]));

    await _pumpChild(
      tester: tester,
      overrides: [searchRepositoryProvider.overrideWithValue(searchRepository)],
      home: const SearchPage(),
      themeMode: ThemeMode.dark,
    );

    expect(find.byType(ShopPageScaffold), findsOneWidget);
    _expectReadableLightScreen(tester, find.text('Search'));
    expect(find.text('Tìm kiếm gần đây'), findsOneWidget);
  });

  testWidgets('notifications keeps light glass surface and readable title', (
    tester,
  ) async {
    when(
      () => notificationRepository.list(
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => const Success(<AppNotification>[]));

    await _pumpChild(
      tester: tester,
      overrides: [
        notificationRepositoryProvider.overrideWithValue(
          notificationRepository,
        ),
      ],
      home: const NotificationsPage(),
      themeMode: ThemeMode.dark,
    );

    _expectReadableLightScreen(tester, find.text('Notifications'));
  });
}
