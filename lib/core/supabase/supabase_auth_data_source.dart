import 'package:base_project/shared/data/models/user_model.dart';

/// Contract for Supabase Auth operations.
abstract interface class SupabaseAuthDataSource {
  Future<UserModel> signInWithPassword({
    required String email,
    required String password,
  });

  Future<UserModel?> getCurrentUser();

  String? get currentAccessToken;

  Future<void> signOut();
}
