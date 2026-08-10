import 'package:base_project/features/notifications/domain/repositories/notification_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifications DI composition root.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  throw UnimplementedError(
    'NotificationRepository is not wired yet. '
    'Register a Supabase-backed implementation in a later milestone.',
  );
});
