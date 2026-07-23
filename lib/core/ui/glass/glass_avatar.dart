import 'package:base_project/core/ui/glass/glass_theme.dart';
import 'package:flutter/material.dart';

class GlassAvatar extends StatelessWidget {
  const GlassAvatar({
    super.key,
    this.image,
    this.initials,
    this.radius = 40,
    this.isLoading = false,
    this.showStatus = false,
    this.statusColor,
  });

  final ImageProvider? image;
  final String? initials;
  final double radius;
  final bool isLoading;
  final bool showStatus;
  final Color? statusColor;

  @override
  Widget build(BuildContext context) {
    final glass = context.glassTheme;
    final colors = context.appColors;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: glass.highlightColor, width: 2),
            color: colors.primaryContainer,
            image: image != null
                ? DecorationImage(image: image!, fit: BoxFit.cover)
                : null,
          ),
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : image == null
              ? Text(
                  _initialsText(initials),
                  style: context.appTypography.titleLarge?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                )
              : null,
        ),
        if (showStatus)
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: statusColor ?? colors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  String _initialsText(String? value) {
    final trimmed = (value ?? '?').trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length.clamp(1, 2))
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
