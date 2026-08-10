import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Observes and exposes the current Supabase auth session state.
abstract interface class SupabaseSessionManager {
  /// Whether a persisted session is considered active.
  bool get hasSession;

  /// Current access token, if any.
  String? get accessToken;

  /// Starts listening for auth state changes.
  Future<void> start();

  /// Stops listeners and clears in-memory session mirrors.
  Future<void> stop();
}

/// Placeholder when Supabase has not been initialized.
final class PendingSupabaseSessionManager implements SupabaseSessionManager {
  @override
  bool get hasSession => false;

  @override
  String? get accessToken => null;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

/// Session mirror backed by [SupabaseClient.auth].
final class SupabaseAuthSessionManager implements SupabaseSessionManager {
  SupabaseAuthSessionManager(this._client);

  final SupabaseClient _client;
  StreamSubscription<AuthState>? _subscription;

  @override
  bool get hasSession => _client.auth.currentSession != null;

  @override
  String? get accessToken => _client.auth.currentSession?.accessToken;

  @override
  Future<void> start() async {
    await _subscription?.cancel();
    _subscription = _client.auth.onAuthStateChange.listen((_) {});
  }

  @override
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
