import 'package:base_project/core/logging/logger_provider.dart';
import 'package:base_project/core/result/result.dart';
import 'package:base_project/features/authentication/di/auth_providers.dart';
import 'package:base_project/features/authentication/domain/entities/user.dart';
import 'package:base_project/shared/session/auth_session_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthSessionNotifier extends StateNotifier<AuthSessionState> {
  AuthSessionNotifier(this._ref) : super(const AuthSessionInitial()) {
    restoreSession();
  }

  final Ref _ref;

  Future<void> restoreSession() async {
    state = const AuthSessionLoading();
    final result = await _ref.read(authRepositoryProvider).restoreSession();
    if (!mounted) {
      return;
    }

    state = switch (result) {
      Success(data: final user) when user != null => AuthSessionAuthenticated(
        user,
      ),
      Success() => const AuthSessionUnauthenticated(),
      Failure(error: final error) => AuthSessionError(error.message),
    };

    if (result case Failure(error: final error)) {
      _ref
          .read(appLoggerProvider)
          .error('Session restore failed at session boundary', error: error);
    }
  }

  void setAuthenticated(User user) {
    state = AuthSessionAuthenticated(user);
  }

  void updateUser(User user) {
    if (state is AuthSessionAuthenticated) {
      state = AuthSessionAuthenticated(user);
    }
  }

  Future<void> logout() async {
    final logger = _ref.read(appLoggerProvider);
    final result = await _ref.read(authRepositoryProvider).logout();
    if (!mounted) {
      return;
    }

    // Always leave authenticated UI; log cleanup failures without flicker.
    if (result case Failure(error: final error)) {
      logger.error('Logout cleanup failed', error: error);
    }
    state = const AuthSessionUnauthenticated();
  }
}

final authSessionProvider =
    StateNotifierProvider<AuthSessionNotifier, AuthSessionState>((ref) {
      return AuthSessionNotifier(ref);
    });
