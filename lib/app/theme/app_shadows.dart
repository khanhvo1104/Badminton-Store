import 'package:flutter/material.dart';

abstract final class AppShadows {
  static List<BoxShadow> soft(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> elevated(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.18),
      blurRadius: 32,
      offset: const Offset(0, 14),
    ),
  ];

  static List<BoxShadow> none = const [];
}
