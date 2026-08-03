import 'package:base_project/core/logging/app_logger.dart';
import 'package:base_project/core/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bootstraps the Supabase client for the current process.
abstract interface class SupabaseInitializer {
  /// Returns whether [initialize] has completed successfully.
  bool get isInitialized;

  /// Loads and configures the Supabase SDK using [config].
  ///
  /// Must be idempotent.
  Future<void> initialize(SupabaseConfig config);
}

/// Initializes [Supabase] from [SupabaseConfig] (URL + publishable/anon key).
final class FlutterSupabaseInitializer implements SupabaseInitializer {
  FlutterSupabaseInitializer(this._logger);

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
        'SupabaseConfig is incomplete. Skipping client initialization. '
        'Set SUPABASE_URL and SUPABASE_ANON_KEY (or SUPABASE_PUBLISHABLE_KEY).',
      );
      return;
    }

    await Supabase.initialize(
      url: config.url,
      publishableKey: config.anonKey,
      debug: config.enableDebugLogs,
    );

    _initialized = true;
    _logger.info('Supabase client initialized for ${config.environment.name}.');
  }
}
