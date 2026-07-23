/// Logical cache key prefixes for in-memory / local caches.
/// Prefer composing with entity ids: `'$categories:$id'`.
abstract final class CacheKeys {
  static const String categories = 'shop.categories';
  static const String brands = 'shop.brands';
  static const String productDetail = 'shop.product';
  static const String productList = 'shop.product_list';
  static const String cart = 'shop.cart';
  static const String favorites = 'shop.favorites';
  static const String orders = 'shop.orders';
  static const String addresses = 'shop.addresses';
  static const String profile = 'shop.profile';
  static const String searchRecent = 'shop.search.recent';
  static const String notifications = 'shop.notifications';
}
