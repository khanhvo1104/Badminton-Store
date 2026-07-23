import 'package:base_project/app/theme/app_motion.dart';
import 'package:flutter/material.dart';

/// Subtle one-shot shimmer for high quality only (not continuous by default).
class ShimmerHighlight extends StatefulWidget {
  const ShimmerHighlight({
    required this.child,
    super.key,
    this.enabled = false,
  });

  final Widget child;
  final bool enabled;

  @override
  State<ShimmerHighlight> createState() => _ShimmerHighlightState();
}

class _ShimmerHighlightState extends State<ShimmerHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant ShimmerHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final allow = widget.enabled && AppMotion.allowContinuousMotion(context);
    if (allow) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || !AppMotion.allowContinuousMotion(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1 + _controller.value * 2, 0),
              end: Alignment(1 + _controller.value * 2, 0),
              colors: const [
                Color(0x00FFFFFF),
                Color(0x33FFFFFF),
                Color(0x00FFFFFF),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
