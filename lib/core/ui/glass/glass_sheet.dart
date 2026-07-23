import 'package:base_project/app/theme/app_motion.dart';
import 'package:base_project/app/theme/app_radius.dart';
import 'package:base_project/core/ui/glass/liquid_glass_container.dart';
import 'package:flutter/material.dart';

Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      final bottom = MediaQuery.viewInsetsOf(context).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: LiquidGlassContainer(
          elevated: true,
          enableBlur: true,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Flexible(child: builder(context)),
            ],
          ),
        ),
      );
    },
  );
}

/// Slide+fade helper when presenting custom routes.
Widget glassSheetTransition(
  BuildContext context,
  Animation<double> animation,
  Widget child,
) {
  if (AppMotion.reduceMotion(context)) {
    return child;
  }
  return FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    ),
  );
}
