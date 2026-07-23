import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/authentication/domain/entities/user.dart';

abstract interface class AuthRepository {
  Future<Result<User>> login({required String email, required String password});

  Future<Result<User?>> restoreSession();

  Future<Result<void>> logout();
}
