import 'package:base_project/features/home/domain/entities/dashboard_item.dart';
import 'package:flutter/material.dart';

class DashboardCard extends StatelessWidget {
  const DashboardCard({required this.item, super.key});

  final DashboardItem item;

  IconData get _icon {
    return switch (item.iconName) {
      'devices' => Icons.devices,
      'security' => Icons.security,
      'notifications' => Icons.notifications_outlined,
      'storage' => Icons.storage_outlined,
      _ => Icons.dashboard_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            child: Icon(_icon),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(item.subtitle, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
