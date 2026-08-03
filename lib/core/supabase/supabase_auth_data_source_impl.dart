import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/supabase/supabase_auth_data_source.dart';
import 'package:base_project/shared/data/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseAuthDataSourceImpl implements SupabaseAuthDataSource {
  SupabaseAuthDataSourceImpl(this._client);

  final SupabaseClient _client;

  @override
  String? get currentAccessToken => _client.auth.currentSession?.accessToken;

  @override
  Future<UserModel?> getCurrentUser() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      return null;
    }

    return _toUserModel(authUser);
  }

  @override
  Future<UserModel> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final authUser = response.user;
      if (authUser == null) {
        throw const AuthenticationException('No user returned from Supabase');
      }
      return _toUserModel(authUser);
    } on AuthException catch (error, stackTrace) {
      throw AuthenticationException(
        error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    } on PostgrestException catch (error, stackTrace) {
      throw DatabaseException(
        error.message,
        code: error.code,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (error, stackTrace) {
      throw AuthenticationException(
        error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  UserModel _toUserModel(User authUser) {
    final metadata = authUser.userMetadata ?? const <String, dynamic>{};
    final rawName =
        metadata['full_name'] ??
        metadata['display_name'] ??
        metadata['name'] ??
        authUser.email?.split('@').first;
    final displayName = rawName is String && rawName.trim().isNotEmpty
        ? rawName.trim()
        : 'User';

    return UserModel(
      id: authUser.id,
      email: authUser.email ?? '',
      displayName: displayName,
    );
  }
}
