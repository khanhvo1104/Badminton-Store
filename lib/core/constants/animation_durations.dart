/// Shared animation durations for shop UI.
/// Prefer app theme motion tokens for glass shell motion;
/// use these for commerce micro-interactions.
abstract final class AnimationDurations {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 420);

  static const Duration cartBadge = Duration(milliseconds: 220);
  static const Duration favoriteToggle = Duration(milliseconds: 200);
  static const Duration pageTransition = Duration(milliseconds: 300);
  static const Duration shimmer = Duration(milliseconds: 1200);
}
