import 'package:base_project/core/supabase/supabase_auth_data_source.dart';
import 'package:base_project/features/authentication/data/data_sources/auth_remote_data_source.dart';
import 'package:base_project/features/authentication/data/models/auth_response_model.dart';
import 'package:base_project/features/authentication/data/models/login_request_model.dart';
import 'package:base_project/shared/data/models/user_model.dart';

final class SupabaseAuthRemoteDataSource implements AuthRemoteDataSource {
  SupabaseAuthRemoteDataSource(this._supabaseAuth);

  final SupabaseAuthDataSource _supabaseAuth;

  @override
  String? get currentAccessToken => _supabaseAuth.currentAccessToken;

  @override
  Future<UserModel?> getCurrentUser() {
    return _supabaseAuth.getCurrentUser();
  }

  @override
  Future<AuthResponseModel> login(LoginRequestModel request) async {
    final user = await _supabaseAuth.signInWithPassword(
      email: request.email,
      password: request.password,
    );
    return AuthResponseModel(accessToken: currentAccessToken ?? '', user: user);
  }

  @override
  Future<void> logout() {
    return _supabaseAuth.signOut();
  }
}
