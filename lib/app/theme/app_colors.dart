import 'package:flutter/material.dart';

abstract final class AppColors {
  /// Bright mint teal — primary seed for light theme.
  static const Color seedLight = Color(0xFF00B894);

  static const Color seedDark = Color(0xFF3DDC97);

  /// Near-white with a soft mint wash.
  static const Color surfaceTintLight = Color(0xFFF5FFFB);

  static const Color surfaceTintDark = Color(0xFF0B1210);

  static const Color glassTintLight = Color(0xF7FFFFFF);
  static const Color glassTintDark = Color(0xCC1A2420);

  /// Vivid teal accent for light UI chrome.
  static const Color accentLight = Color(0xFF00A884);

  static const Color accentDark = Color(0xFF5EE6B0);

  static const Color destructive = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF12B886);
}
