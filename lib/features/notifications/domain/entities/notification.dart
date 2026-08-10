import 'package:meta/meta.dart';

enum NotificationType { orderUpdate, promotion, system, stockAlert }

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    this.payload,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final bool isRead;
  final Map<String, String>? payload;
  final DateTime? createdAt;

  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    NotificationType? type,
    bool? isRead,
    Map<String, String>? payload,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AppNotification &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            userId == other.userId &&
            title == other.title &&
            body == other.body &&
            type == other.type &&
            isRead == other.isRead &&
            _mapEquals(payload, other.payload) &&
            createdAt == other.createdAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    title,
    body,
    type,
    isRead,
    payload == null
        ? null
        : Object.hashAll(
            payload!.entries.map((e) => Object.hash(e.key, e.value)),
          ),
    createdAt,
  );
}

bool _mapEquals(Map<String, String>? a, Map<String, String>? b) {
  if (identical(a, b)) {
    return true;
  }
  if (a == null || b == null) {
    return a == b;
  }
  if (a.length != b.length) {
    return false;
  }
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
