import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 360);
  static const Duration emphasized = Duration(milliseconds: 480);
  static const Duration ambient = Duration(seconds: 18);

  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve entranceCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
  static const Curve emphasizedCurve = Curves.easeInOutCubic;

  static bool reduceMotion(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context);
  }

  /// Continuous decorative motion (ambient blobs, sheen).
  /// Off under reduce-motion and in widget tests so pumpAndSettle can finish.
  static bool allowContinuousMotion(BuildContext context) {
    if (_isWidgetTestBinding) {
      return false;
    }
    return !reduceMotion(context);
  }

  static bool get _isWidgetTestBinding {
    return WidgetsBinding.instance.runtimeType.toString().contains(
      'TestWidgetsFlutterBinding',
    );
  }
}
