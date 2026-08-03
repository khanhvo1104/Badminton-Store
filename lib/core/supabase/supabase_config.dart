import 'package:base_project/core/config/app_environment.dart';

/// Immutable Supabase connection settings loaded from environment.
///
/// Does not open a client connection by itself. See `SupabaseInitializer`.
///
/// [anonKey] accepts either the legacy anon key or the publishable key
/// (`sb_publishable_...`). Never store the service_role key here.
class SupabaseConfig {
  const SupabaseConfig({
    required this.environment,
    required this.url,
    required this.anonKey,
    this.enableDebugLogs = false,
  });

  final AppEnvironment environment;
  final String url;

  /// Publishable / anon key used by the Flutter client.
  final String anonKey;
  final bool enableDebugLogs;

  bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
