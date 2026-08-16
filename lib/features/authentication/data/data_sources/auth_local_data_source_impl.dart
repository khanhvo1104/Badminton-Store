import 'package:base_project/core/constants/storage_keys.dart';
import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/storage/secure_storage_service.dart';
import 'package:base_project/features/authentication/data/data_sources/auth_local_data_source.dart';
import 'package:base_project/shared/data/models/user_model.dart';

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl(this._secureStorage);

  final SecureStorageService _secureStorage;

  @override
  Future<void> saveSession({
    required String accessToken,
    required UserModel user,
  }) async {
    try {
      await _secureStorage.write(
        key: StorageKeys.accessToken,
        value: accessToken,
      );
      await _secureStorage.write(key: StorageKeys.userId, value: user.id);
      await _secureStorage.write(key: StorageKeys.userEmail, value: user.email);
      await _secureStorage.write(
        key: StorageKeys.userDisplayName,
        value: user.displayName,
      );
    } on Object catch (error, stackTrace) {
      throw CacheException(
        'Failed to persist session',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<String?> readAccessToken() async {
    try {
      return await _secureStorage.read(key: StorageKeys.accessToken);
    } on Object catch (error, stackTrace) {
      throw CacheException(
        'Failed to read access token',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<UserModel?> readCachedUser() async {
    try {
      final id = await _secureStorage.read(key: StorageKeys.userId);
      final email = await _secureStorage.read(key: StorageKeys.userEmail);
      final displayName = await _secureStorage.read(
        key: StorageKeys.userDisplayName,
      );

      if (id == null || email == null || displayName == null) {
        return null;
      }

      return UserModel(id: id, email: email, displayName: displayName);
    } on Object catch (error, stackTrace) {
      throw CacheException(
        'Failed to read cached user',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> clearSession() async {
    try {
      await _secureStorage.clearSession();
    } on Object catch (error, stackTrace) {
      throw CacheException(
        'Failed to clear session',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
