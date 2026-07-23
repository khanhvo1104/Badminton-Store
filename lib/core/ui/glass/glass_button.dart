import 'package:base_project/app/theme/app_colors.dart';
import 'package:base_project/app/theme/app_motion.dart';
import 'package:base_project/app/theme/app_radius.dart';
import 'package:base_project/core/ui/glass/glass_theme.dart';
import 'package:flutter/material.dart';

enum GlassButtonVariant { primary, secondary, destructive, text }

class GlassButton extends StatefulWidget {
  const GlassButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = GlassButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final GlassButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final bool expanded;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final glass = context.glassTheme;
    final colors = context.appColors;

    final Gradient? gradient = switch (widget.variant) {
      GlassButtonVariant.primary => LinearGradient(
        colors: [
          colors.primary,
          Color.lerp(colors.primary, colors.tertiary, 0.35)!,
        ],
      ),
      GlassButtonVariant.destructive => const LinearGradient(
        colors: [AppColors.destructive, Color(0xFFB83232)],
      ),
      _ => null,
    };

    final bg = switch (widget.variant) {
      GlassButtonVariant.secondary => glass.elevatedSurfaceColor,
      GlassButtonVariant.text => Colors.transparent,
      _ => colors.primary,
    };

    final fg = switch (widget.variant) {
      GlassButtonVariant.primary ||
      GlassButtonVariant.destructive => colors.onPrimary,
      _ => colors.onSurface,
    };

    final child = AnimatedScale(
      scale: _pressed && _enabled ? 0.97 : 1,
      duration: AppMotion.fast,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: gradient == null ? bg : null,
            gradient: gradient,
            border: widget.variant == GlassButtonVariant.secondary
                ? Border.all(color: glass.borderColor)
                : null,
            boxShadow: widget.variant == GlassButtonVariant.primary
                ? [
                    BoxShadow(
                      color: glass.accentGlowColor,
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisSize: widget.expanded
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                else ...[
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 18, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      style: context.appTypography.labelLarge?.copyWith(
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: FocusableActionDetector(
        enabled: _enabled,
        onShowFocusHighlight: (_) {},
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: _enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: GestureDetector(
            onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
            onTapCancel: () => setState(() => _pressed = false),
            onTap: _enabled ? widget.onPressed : null,
            child: Opacity(opacity: _enabled ? 1 : 0.5, child: child),
          ),
        ),
      ),
    );
  }
}
