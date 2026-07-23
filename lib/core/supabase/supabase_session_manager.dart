/// Observes and exposes the current Supabase auth session state.
///
/// Shop Foundation only defines the contract. No Auth listeners are attached.
abstract interface class SupabaseSessionManager {
  /// Whether a persisted session is considered active.
  bool get hasSession;

  /// Current access token, if any. Null until Auth is wired.
  String? get accessToken;

  /// Starts listening for auth state changes.
  ///
  /// Must be a no-op until the Supabase client is initialized.
  Future<void> start();

  /// Stops listeners and clears in-memory session mirrors.
  Future<void> stop();
}

/// Placeholder session manager used before Supabase Auth is connected.
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
