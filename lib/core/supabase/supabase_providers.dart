import 'package:base_project/core/config/app_environment.dart';
import 'package:base_project/core/config/environment_provider.dart';
import 'package:base_project/core/logging/logger_provider.dart';
import 'package:base_project/core/supabase/supabase_auth_data_source.dart';
import 'package:base_project/core/supabase/supabase_config.dart';
import 'package:base_project/core/supabase/supabase_database.dart';
import 'package:base_project/core/supabase/supabase_exception_mapper.dart';
import 'package:base_project/core/supabase/supabase_initializer.dart';
import 'package:base_project/core/supabase/supabase_session_manager.dart';
import 'package:base_project/core/supabase/supabase_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Builds [SupabaseConfig] from dart-defines / dotenv without opening a client.
final supabaseConfigProvider = Provider<SupabaseConfig>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  return _loadSupabaseConfig(environment);
});

final supabaseInitializerProvider = Provider<SupabaseInitializer>((ref) {
  return PendingSupabaseInitializer(ref.watch(appLoggerProvider));
});

final supabaseSessionManagerProvider = Provider<SupabaseSessionManager>((ref) {
  return PendingSupabaseSessionManager();
});

final supabaseExceptionMapperProvider = Provider<SupabaseExceptionMapper>((
  ref,
) {
  return SupabaseExceptionMapper(ref.watch(appLoggerProvider));
});

/// Auth / DB / Storage facades are registered but not implemented yet.
final supabaseAuthDataSourceProvider = Provider<SupabaseAuthDataSource>((ref) {
  throw UnimplementedError(
    'SupabaseAuthDataSource is not wired. '
    'Connect supabase_flutter in a later milestone.',
  );
});

final supabaseDatabaseProvider = Provider<SupabaseDatabase>((ref) {
  throw UnimplementedError(
    'SupabaseDatabase is not wired. '
    'Connect PostgREST accessors in a later milestone.',
  );
});

final supabaseStorageProvider = Provider<SupabaseStorage>((ref) {
  throw UnimplementedError(
    'SupabaseStorage is not wired. '
    'Connect Storage buckets in a later milestone.',
  );
});

SupabaseConfig _loadSupabaseConfig(AppEnvironment environment) {
  const definedUrl = String.fromEnvironment('SUPABASE_URL');
  const definedAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  const definedLogs = String.fromEnvironment('ENABLE_NETWORK_LOGS');

  final url = definedUrl.isNotEmpty
      ? definedUrl
      : dotenv.get('SUPABASE_URL', fallback: '');
  final anonKey = definedAnonKey.isNotEmpty
      ? definedAnonKey
      : dotenv.get('SUPABASE_ANON_KEY', fallback: '');

  final enableDebugLogs = definedLogs.isNotEmpty
      ? definedLogs == 'true'
      : dotenv.get('ENABLE_NETWORK_LOGS', fallback: 'false') == 'true';

  return SupabaseConfig(
    environment: environment,
    url: url,
    anonKey: anonKey,
    enableDebugLogs: enableDebugLogs,
  );
}
