import 'package:base_project/app/theme/app_motion.dart';
import 'package:flutter/material.dart';

class PressScaleAnimation extends StatelessWidget {
  const PressScaleAnimation({
    required this.pressed,
    required this.child,
    super.key,
    this.scale = 0.97,
  });

  final bool pressed;
  final Widget child;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: pressed ? scale : 1,
      duration: AppMotion.fast,
      curve: AppMotion.standardCurve,
      child: child,
    );
  }
}
