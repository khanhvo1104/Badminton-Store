import 'package:base_project/core/constants/storage_keys.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstraction over secure storage so presentation never depends on plugins.
abstract interface class SecureStorageService {
  Future<void> write({required String key, required String value});

  Future<String?> read({required String key});

  Future<void> delete({required String key});

  Future<void> clearSession();
}

class SecureStorageServiceImpl implements SecureStorageService {
  SecureStorageServiceImpl({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _storage;

  static const _sessionKeys = [
    StorageKeys.accessToken,
    StorageKeys.userId,
    StorageKeys.userEmail,
    StorageKeys.userDisplayName,
  ];

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<String?> read({required String key}) {
    return _storage.read(key: key);
  }

  @override
  Future<void> delete({required String key}) {
    return _storage.delete(key: key);
  }

  @override
  Future<void> clearSession() async {
    for (final key in _sessionKeys) {
      await _storage.delete(key: key);
    }
  }
}

/// In-memory fake used by tests and environments without secure storage.
class FakeSecureStorageService implements SecureStorageService {
  final Map<String, String> _values = {};

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<void> clearSession() async {
    _values
      ..remove(StorageKeys.accessToken)
      ..remove(StorageKeys.userId)
      ..remove(StorageKeys.userEmail)
      ..remove(StorageKeys.userDisplayName);
  }
}
