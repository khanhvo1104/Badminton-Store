import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/notifications/domain/entities/notification.dart';

/// In-app notifications. Implementations arrive in a later milestone.
abstract interface class NotificationRepository {
  Future<Result<List<AppNotification>>> list({int page = 1, int pageSize = 20});

  Future<Result<void>> markRead(String id);

  Future<Result<void>> markAllRead();

  Future<Result<int>> unreadCount();
}
