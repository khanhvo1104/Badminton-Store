import 'package:base_project/core/supabase/supabase_providers.dart';
import 'package:base_project/features/notifications/data/repositories/supabase_notification_repository.dart';
import 'package:base_project/features/notifications/domain/repositories/notification_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifications DI composition root.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return SupabaseNotificationRepository(ref.watch(supabaseClientProvider));
});
