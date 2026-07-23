import 'package:base_project/app/theme/app_motion.dart';
import 'package:flutter/material.dart';

class FadeScaleTransition extends StatelessWidget {
  const FadeScaleTransition({
    required this.animation,
    required this.child,
    super.key,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) {
      return child;
    }
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(
          CurvedAnimation(parent: animation, curve: AppMotion.entranceCurve),
        ),
        child: child,
      ),
    );
  }
}
