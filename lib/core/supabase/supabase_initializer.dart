import 'package:base_project/core/logging/app_logger.dart';
import 'package:base_project/core/supabase/supabase_config.dart';

/// Bootstraps the Supabase client for the current process.
///
/// Shop Foundation only prepares the contract — no network calls are made.
abstract interface class SupabaseInitializer {
  /// Returns whether [initialize] has completed successfully.
  bool get isInitialized;

  /// Loads and configures the Supabase SDK using [config].
  ///
  /// Must be idempotent. Implementations must not perform REST/Auth calls.
  Future<void> initialize(SupabaseConfig config);
}

/// No-op initializer used until the Supabase SDK is wired in a later milestone.
final class PendingSupabaseInitializer implements SupabaseInitializer {
  PendingSupabaseInitializer(this._logger);

  final AppLogger _logger;
  bool _initialized = false;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize(SupabaseConfig config) async {
    if (_initialized) {
      return;
    }

    if (!config.isConfigured) {
      _logger.warning(
        'SupabaseConfig is incomplete. Skipping client initialization.',
      );
      return;
    }

    // Intentionally deferred: supabase_flutter.initialize belongs in a
    // later infrastructure milestone. Config is validated only.
    _logger.info(
      'Supabase initializer ready for ${config.environment.name} '
      '(client not started).',
    );
    _initialized = true;
  }
}
