import 'package:base_project/core/config/app_environment.dart';

/// Immutable Supabase connection settings loaded from environment.
///
/// Does not open a client connection. See `SupabaseInitializer`.
class SupabaseConfig {
  const SupabaseConfig({
    required this.environment,
    required this.url,
    required this.anonKey,
    this.enableDebugLogs = false,
  });

  final AppEnvironment environment;
  final String url;
  final String anonKey;
  final bool enableDebugLogs;

  bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
