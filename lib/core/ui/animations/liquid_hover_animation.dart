import 'package:base_project/app/theme/app_motion.dart';
import 'package:flutter/material.dart';

/// Desktop hover lift without continuous animation.
class LiquidHoverAnimation extends StatefulWidget {
  const LiquidHoverAnimation({
    required this.child,
    super.key,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  State<LiquidHoverAnimation> createState() => _LiquidHoverAnimationState();
}

class _LiquidHoverAnimationState extends State<LiquidHoverAnimation> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || AppMotion.reduceMotion(context)) {
      return widget.child;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedTranslate(
        offset: _hovered ? const Offset(0, -2) : Offset.zero,
        child: widget.child,
      ),
    );
  }
}

class AnimatedTranslate extends StatelessWidget {
  const AnimatedTranslate({
    required this.offset,
    required this.child,
    super.key,
  });

  final Offset offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.fast,
      transform: Matrix4.translationValues(offset.dx, offset.dy, 0),
      child: child,
    );
  }
}
