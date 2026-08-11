import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/features/notifications/domain/entities/notification.dart';
import 'package:flutter/material.dart';

/// Formats a notification timestamp with the active Material locale.
///
/// Uses [MaterialLocalizations] so date/time order and separators follow the
/// app/context locale rather than a hard-coded pattern.
String formatNotificationTimestamp(
  DateTime? createdAt, {
  required MaterialLocalizations localizations,
  bool alwaysUse24HourFormat = false,
}) {
  if (createdAt == null) {
    return '';
  }
  final local = createdAt.toLocal();
  final date = localizations.formatShortDate(local);
  final time = localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
    alwaysUse24HourFormat: alwaysUse24HourFormat,
  );
  return '$date $time';
}

IconData notificationTypeIcon(NotificationType type) {
  return switch (type) {
    NotificationType.orderUpdate => Icons.local_shipping_outlined,
    NotificationType.promotion => Icons.local_offer_outlined,
    NotificationType.system => Icons.info_outline,
    NotificationType.stockAlert => Icons.inventory_2_outlined,
  };
}

String notificationTypeLabel(NotificationType type) {
  return switch (type) {
    NotificationType.orderUpdate => 'Order update',
    NotificationType.promotion => 'Promotion',
    NotificationType.system => 'System',
    NotificationType.stockAlert => 'Stock alert',
  };
}

class NotificationListItem extends StatelessWidget {
  const NotificationListItem({
    required this.notification,
    required this.isMarkingRead,
    required this.onTap,
    super.key,
  });

  final AppNotification notification;
  final bool isMarkingRead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !notification.isRead;
    final timestamp = formatNotificationTimestamp(
      notification.createdAt,
      localizations: MaterialLocalizations.of(context),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

    return Material(
      key: Key('notifications_item_${notification.id}'),
      color: unread
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                notificationTypeIcon(notification.type),
                key: Key('notifications_item_type_${notification.id}'),
                semanticLabel: notificationTypeLabel(notification.type),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            key: Key(
                              'notifications_item_title_${notification.id}',
                            ),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (unread)
                          Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.xs),
                            child: Icon(
                              Icons.circle,
                              key: Key(
                                'notifications_item_unread_${notification.id}',
                              ),
                              size: 8,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        if (isMarkingRead)
                          const Padding(
                            padding: EdgeInsets.only(left: AppSpacing.xs),
                            child: SizedBox(
                              key: Key('notifications_item_marking'),
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      notification.body,
                      key: Key('notifications_item_body_${notification.id}'),
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (timestamp.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        timestamp,
                        key: Key(
                          'notifications_item_timestamp_${notification.id}',
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
