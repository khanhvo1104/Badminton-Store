import 'package:base_project/core/errors/app_exception.dart';

typedef SupabaseRow = Map<String, dynamic>;

String requireString(SupabaseRow row, String key) {
  final value = row[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw DatabaseException('Missing required field: $key');
}

String? optionalString(SupabaseRow row, String key) {
  final value = row[key];
  return value is String && value.isNotEmpty ? value : null;
}

bool requireBool(SupabaseRow row, String key, {bool fallback = false}) {
  final value = row[key];
  return value is bool ? value : fallback;
}

int requireInt(SupabaseRow row, String key, {int fallback = 0}) {
  final value = row[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return fallback;
}

double requireDouble(SupabaseRow row, String key, {double fallback = 0}) {
  final value = row[key];
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  if (value is num) {
    return value.toDouble();
  }
  return fallback;
}

DateTime? optionalDateTime(SupabaseRow row, String key) {
  final value = row[key];
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

Map<String, Object?> requireJsonMap(SupabaseRow row, String key) {
  final value = row[key];
  if (value is Map) {
    return value.map(
      (dynamic mapKey, dynamic mapValue) =>
          MapEntry(mapKey.toString(), mapValue as Object?),
    );
  }
  return const {};
}
