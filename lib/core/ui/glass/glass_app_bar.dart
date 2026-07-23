import 'dart:ui';

import 'package:base_project/core/ui/glass/glass_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle = false,
    this.blurred = true,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool blurred;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final glass = context.glassTheme;
    final useBlur = blurred && glass.blurEnabled;

    return AppBar(
      title: title,
      leading: leading,
      actions: actions,
      centerTitle: centerTitle,
      backgroundColor: useBlur
          ? Colors.transparent
          : glass.surfaceColor.withValues(alpha: 0.92),
      elevation: 0,
      scrolledUnderElevation: useBlur ? 0.5 : 0,
      flexibleSpace: useBlur
          ? ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: ColoredBox(
                  color: glass.surfaceColor.withValues(alpha: 0.55),
                ),
              ),
            )
          : null,
      systemOverlayStyle: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    );
  }
}
