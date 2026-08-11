import 'package:base_project/core/ui/glass/glass_card.dart';
import 'package:base_project/features/home/domain/entities/dashboard_item.dart';
import 'package:flutter/material.dart';

class FeaturedProductCard extends StatelessWidget {
  const FeaturedProductCard({
    required this.item,
    required this.onTap,
    super.key,
  });

  final DashboardItem item;
  final VoidCallback onTap;

  IconData get _icon {
    return switch (item.iconName) {
      'devices' => Icons.devices,
      'security' => Icons.security,
      'notifications' => Icons.notifications_outlined,
      'storage' => Icons.storage_outlined,
      'sports' => Icons.sports_tennis,
      'footwear' => Icons.directions_run,
      'inventory' => Icons.inventory_2_outlined,
      _ => Icons.sports_tennis_outlined,
    };
  }

  String get semanticsLabel => item.title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: FocusableActionDetector(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onTap();
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: GlassCard(
              variant: GlassCardVariant.interactive,
              margin: EdgeInsets.zero,
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                      child: Icon(_icon),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            item.subtitle,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  ExcludeSemantics(
                    child: Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
