import 'package:base_project/core/errors/app_exception.dart';
import 'package:base_project/core/supabase/supabase_row.dart';
import 'package:base_project/features/profile/data/data_sources/profile_remote_data_source.dart';
import 'package:base_project/features/profile/data/models/update_profile_request_model.dart';
import 'package:base_project/shared/data/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseProfileRemoteDataSource implements ProfileRemoteDataSource {
  SupabaseProfileRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<UserModel> fetchProfile() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const UnauthorizedException('Please sign in to view your profile');
    }

    try {
      final response = await _client
          .from('profiles')
          .select('id, full_name')
          .eq('id', authUser.id)
          .maybeSingle();

      final row = response == null ? null : Map<String, dynamic>.from(response);
      final displayName =
          optionalString(row ?? const {}, 'full_name') ??
          authUser.userMetadata?['full_name'] as String? ??
          authUser.userMetadata?['display_name'] as String? ??
          authUser.email?.split('@').first ??
          'User';

      return UserModel(
        id: authUser.id,
        email: authUser.email ?? '',
        displayName: displayName,
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
  Future<UserModel> updateProfile(UpdateProfileRequestModel request) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const UnauthorizedException('Please sign in to update your profile');
    }

    try {
      final updated = await _client
          .from('profiles')
          .update({'full_name': request.displayName.trim()})
          .eq('id', authUser.id)
          .select('id, full_name')
          .single();
      final row = Map<String, dynamic>.from(updated);
      return UserModel(
        id: requireString(row, 'id'),
        email: authUser.email ?? '',
        displayName: optionalString(row, 'full_name') ?? request.displayName,
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
}
