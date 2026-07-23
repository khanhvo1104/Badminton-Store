import 'package:flutter/material.dart';

/// Soft top-edge highlight and restrained sheen for glass surfaces.
class GlassHighlightPainter extends CustomPainter {
  GlassHighlightPainter({
    required this.highlightColor,
    required this.reflectionColor,
    required this.radius,
    required this.highlightWidth,
    this.progress = 0,
  });

  final Color highlightColor;
  final Color reflectionColor;
  final double radius;
  final double highlightWidth;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas
      ..save()
      ..clipRRect(rrect);

    final edgePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [highlightColor, highlightColor.withValues(alpha: 0)],
        stops: const [0, 0.22],
      ).createShader(Offset.zero & size)
      ..strokeWidth = highlightWidth
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(rrect.deflate(0.5), edgePaint);

    final sheenCenter = Offset(
      size.width * (0.18 + progress * 0.08),
      size.height * 0.12,
    );
    final sheenPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [reflectionColor, reflectionColor.withValues(alpha: 0)],
          ).createShader(
            Rect.fromCircle(
              center: sheenCenter,
              radius: size.shortestSide * 0.55,
            ),
          );
    canvas
      ..drawCircle(sheenCenter, size.shortestSide * 0.55, sheenPaint)
      ..restore();
  }

  @override
  bool shouldRepaint(covariant GlassHighlightPainter oldDelegate) {
    return oldDelegate.highlightColor != highlightColor ||
        oldDelegate.reflectionColor != reflectionColor ||
        oldDelegate.radius != radius ||
        oldDelegate.highlightWidth != highlightWidth ||
        oldDelegate.progress != progress;
  }
}
