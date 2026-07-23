/// Soft limits for API payloads and client-side guards.
abstract final class ApiLimits {
  static const int maxSearchQueryLength = 120;
  static const int maxCartItems = 50;
  static const int maxQuantityPerItem = 99;
  static const int maxFavoriteItems = 500;
  static const int maxAddresses = 20;
  static const int maxProductImages = 12;
  static const int maxVariantsPerProduct = 100;
  static const int maxRecentSearches = 10;
  static const int maxUploadBytes = 5 * 1024 * 1024;
}
