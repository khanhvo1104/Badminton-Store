import 'package:base_project/features/authentication/domain/entities/user.dart';

/// Immutable authentication session state observed by routing and UI.
sealed class AuthSessionState {
  const AuthSessionState();
}

final class AuthSessionInitial extends AuthSessionState {
  const AuthSessionInitial();
}

final class AuthSessionLoading extends AuthSessionState {
  const AuthSessionLoading();
}

final class AuthSessionAuthenticated extends AuthSessionState {
  const AuthSessionAuthenticated(this.user);

  final User user;
}

final class AuthSessionUnauthenticated extends AuthSessionState {
  const AuthSessionUnauthenticated();
}

/// Session restore failed; UI should offer retry (not treat as logged out silently).
final class AuthSessionError extends AuthSessionState {
  const AuthSessionError(this.message);

  final String message;
}
