import 'package:base_project/core/ui/glass/glass_theme.dart';
import 'package:flutter/material.dart';

class GlassLoadingIndicator extends StatelessWidget {
  const GlassLoadingIndicator({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: colors.primary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
