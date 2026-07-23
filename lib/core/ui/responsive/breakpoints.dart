import 'package:flutter/material.dart';

abstract final class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;

  static bool isTabletOrLarger(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mobile;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;

  static double contentMaxWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= tablet) {
      return 960;
    }
    if (width >= mobile) {
      return 720;
    }
    return double.infinity;
  }
}
