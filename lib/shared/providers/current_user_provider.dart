import 'package:base_project/features/authentication/domain/entities/user.dart';
import 'package:base_project/shared/session/auth_session_provider.dart';
import 'package:base_project/shared/session/auth_session_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared read-only access to the authenticated user.
final currentUserProvider = Provider<User?>((ref) {
  final session = ref.watch(authSessionProvider);
  return session is AuthSessionAuthenticated ? session.user : null;
});
