/// Canonical image dimensions for product media and avatars.
/// Values are logical pixels; decode/cache at device pixel ratio separately.
abstract final class ImageSizes {
  static const double thumbnail = 96;
  static const double card = 200;
  static const double detail = 600;
  static const double hero = 1200;
  static const double avatar = 64;
  static const double avatarLarge = 128;

  static const double brandLogo = 48;
  static const double categoryIcon = 72;
}
