import 'package:base_project/core/config/demo_credentials.dart';
import 'package:base_project/core/constants/storage_keys.dart';
import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/storage/secure_storage_service.dart';
import 'package:base_project/features/profile/data/data_sources/profile_remote_data_source.dart';
import 'package:base_project/features/profile/data/models/update_profile_request_model.dart';
import 'package:base_project/shared/data/models/user_model.dart';

class FakeProfileRemoteDataSource implements ProfileRemoteDataSource {
  FakeProfileRemoteDataSource({
    required SecureStorageService secureStorage,
    this.delay = const Duration(milliseconds: 450),
  }) : _secureStorage = secureStorage;

  final SecureStorageService _secureStorage;
  final Duration delay;

  UserModel _user = const UserModel(
    id: 'user-001',
    email: DemoCredentials.email,
    displayName: 'Demo User',
  );

  @override
  Future<UserModel> fetchProfile() async {
    await Future<void>.delayed(delay);
    final cachedName = await _secureStorage.read(
      key: StorageKeys.userDisplayName,
    );
    final cachedEmail = await _secureStorage.read(key: StorageKeys.userEmail);
    final cachedId = await _secureStorage.read(key: StorageKeys.userId);

    if (cachedId != null && cachedEmail != null && cachedName != null) {
      _user = UserModel(
        id: cachedId,
        email: cachedEmail,
        displayName: cachedName,
      );
    }

    return _user;
  }

  @override
  Future<UserModel> updateProfile(UpdateProfileRequestModel request) async {
    await Future<void>.delayed(delay);

    if (request.displayName.trim().isEmpty) {
      throw const ValidationException('Display name cannot be empty');
    }

    _user = _user.copyWith(displayName: request.displayName.trim());
    await _secureStorage.write(
      key: StorageKeys.userDisplayName,
      value: _user.displayName,
    );
    return _user;
  }
}
