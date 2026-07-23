import 'package:base_project/app/theme/app_motion.dart';
import 'package:base_project/core/ui/glass/glass_button.dart';
import 'package:base_project/core/ui/glass/glass_panel.dart';
import 'package:flutter/material.dart';

Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required String title,
  required String description,
  String confirmLabel = 'OK',
  String? cancelLabel,
  bool barrierDismissible = true,
}) {
  final reduce = AppMotion.reduceMotion(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    transitionDuration: reduce ? Duration.zero : AppMotion.standard,
    pageBuilder: (context, animation, secondaryAnimation) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Material(
            type: MaterialType.transparency,
            child: GlassPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (cancelLabel != null) ...[
                        GlassButton(
                          label: cancelLabel,
                          variant: GlassButtonVariant.text,
                          expanded: false,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 8),
                      ],
                      GlassButton(
                        label: confirmLabel,
                        expanded: false,
                        onPressed: () => Navigator.of(context).pop(true as T?),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      if (reduce) {
        return child;
      }
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
          child: child,
        ),
      );
    },
  );
}
