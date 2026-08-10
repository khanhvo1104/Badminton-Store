/// Display and formatting defaults for money.
/// Amounts in domain entities should be stored in minor units (e.g. cents)
/// or as decimal-compatible strings once a money package is introduced.
abstract final class CurrencyConstants {
  static const String defaultCurrencyCode = 'VND';
  static const String defaultCurrencySymbol = '₫';
  static const int defaultFractionDigits = 0;
  static const String locale = 'vi_VN';
}
