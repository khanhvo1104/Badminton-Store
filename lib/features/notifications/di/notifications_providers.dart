import 'dart:math' as math;

import 'package:base_project/core/result/result.dart';
import 'package:base_project/core/supabase/supabase_providers.dart';
import 'package:base_project/features/notifications/data/repositories/supabase_notification_repository.dart';
import 'package:base_project/features/notifications/domain/repositories/notification_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifications DI composition root.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return SupabaseNotificationRepository(ref.watch(supabaseClientProvider));
});

/// Best-effort unread count for Profile surfaces.
final notificationUnreadCountProvider =
    AsyncNotifierProvider.autoDispose<NotificationUnreadCountController, int?>(
      NotificationUnreadCountController.new,
    );

class NotificationUnreadCountController extends AutoDisposeAsyncNotifier<int?> {
  @override
  Future<int?> build() => _loadUnreadCount();

  Future<void> refresh() async {
    state = const AsyncLoading<int?>();
    state = AsyncData(await _loadUnreadCount());
  }

  Future<int?> _loadUnreadCount() async {
    final result = await ref.read(notificationRepositoryProvider).unreadCount();

    return switch (result) {
      Success(data: final count) => math.max(0, count),
      Failure() => null,
    };
  }
}
