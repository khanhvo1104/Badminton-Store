import 'dart:math' as math;

import 'package:base_project/app/theme/app_motion.dart';
import 'package:base_project/core/ui/glass/glass_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class GlassBackground extends StatefulWidget {
  const GlassBackground({
    required this.child,
    super.key,
    this.enableAmbientMotion = true,
  });

  final Widget child;
  final bool enableAmbientMotion;

  @override
  State<GlassBackground> createState() => _GlassBackgroundState();
}

class _GlassBackgroundState extends State<GlassBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.ambient);
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.resumed) {
          _syncMotion();
        } else {
          _controller.stop();
        }
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant GlassBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  void _syncMotion() {
    final glass = context.glassTheme;
    final allow =
        widget.enableAmbientMotion &&
        AppMotion.allowContinuousMotion(context) &&
        glass.blurEnabled &&
        SchedulerBinding.instance.lifecycleState != AppLifecycleState.paused;

    if (allow) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller
        ..stop()
        ..value = 0.35;
    }
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glassTheme;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: glass.backgroundGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                return CustomPaint(
                  painter: _AmbientBlobsPainter(
                    progress: t,
                    accent: glass.accentGlowColor,
                    overlay: glass.backgroundOverlay,
                  ),
                );
              },
            ),
          ),
          ColoredBox(color: glass.backgroundOverlay),
          widget.child,
        ],
      ),
    );
  }
}

class _AmbientBlobsPainter extends CustomPainter {
  _AmbientBlobsPainter({
    required this.progress,
    required this.accent,
    required this.overlay,
  });

  final double progress;
  final Color accent;
  final Color overlay;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final dx = math.sin(progress * math.pi) * 24;
    final dy = math.cos(progress * math.pi) * 18;

    paint.color = accent.withValues(alpha: 0.35);
    canvas.drawCircle(
      Offset(size.width * 0.18 + dx, size.height * 0.22 + dy),
      size.shortestSide * 0.42,
      paint,
    );

    paint.color = accent.withValues(alpha: 0.22);
    canvas.drawCircle(
      Offset(size.width * 0.82 - dx, size.height * 0.28 - dy),
      size.shortestSide * 0.36,
      paint,
    );

    paint.color = overlay.withValues(alpha: 0.4);
    canvas.drawCircle(
      Offset(size.width * 0.55, size.height * 0.78 + dy * 0.5),
      size.shortestSide * 0.48,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AmbientBlobsPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accent != accent ||
        oldDelegate.overlay != overlay;
  }
}
