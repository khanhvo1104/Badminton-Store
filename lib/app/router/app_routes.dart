abstract final class AppRoutes {
  static const String root = '/';
  static const String splash = '/splash';
  static const String login = '/login';
  static const String home = '/home';
  static const String catalog = '/catalog';
  static const String product = '/product/:id';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String orders = '/orders';
  static const String favorites = '/favorites';
  static const String profile = '/profile';
  static const String addresses = '/addresses';
  static const String search = '/search';
  static const String settings = '/settings';
  static const String notifications = '/notifications';
  static const String designSystem = '/design-system';

  static const String rootName = 'root';
  static const String splashName = 'splash';
  static const String loginName = 'login';
  static const String homeName = 'home';
  static const String catalogName = 'catalog';
  static const String productName = 'product';
  static const String cartName = 'cart';
  static const String checkoutName = 'checkout';
  static const String ordersName = 'orders';
  static const String favoritesName = 'favorites';
  static const String profileName = 'profile';
  static const String addressesName = 'addresses';
  static const String searchName = 'search';
  static const String settingsName = 'settings';
  static const String notificationsName = 'notifications';
  static const String designSystemName = 'design-system';

  static String productDetail(String id) => '/product/$id';
}
