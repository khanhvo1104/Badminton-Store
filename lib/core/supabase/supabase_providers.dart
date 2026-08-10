import 'package:base_project/core/config/app_environment.dart';
import 'package:base_project/core/config/environment_provider.dart';
import 'package:base_project/core/logging/logger_provider.dart';
import 'package:base_project/core/supabase/supabase_auth_data_source.dart';
import 'package:base_project/core/supabase/supabase_auth_data_source_impl.dart';
import 'package:base_project/core/supabase/supabase_config.dart';
import 'package:base_project/core/supabase/supabase_database.dart';
import 'package:base_project/core/supabase/supabase_exception_mapper.dart';
import 'package:base_project/core/supabase/supabase_initializer.dart';
import 'package:base_project/core/supabase/supabase_session_manager.dart';
import 'package:base_project/core/supabase/supabase_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Builds [SupabaseConfig] from dart-defines / dotenv without opening a client.
final supabaseConfigProvider = Provider<SupabaseConfig>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  return loadSupabaseConfig(environment);
});

final supabaseInitializerProvider = Provider<SupabaseInitializer>((ref) {
  return FlutterSupabaseInitializer(ref.watch(appLoggerProvider));
});

/// Shared Supabase client. Requires successful bootstrap initialization.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  final initializer = ref.watch(supabaseInitializerProvider);
  if (!initializer.isInitialized) {
    throw StateError(
      'Supabase is not initialized. Check SUPABASE_URL and keys in .env.',
    );
  }
  return Supabase.instance.client;
});

final supabaseSessionManagerProvider = Provider<SupabaseSessionManager>((ref) {
  final initializer = ref.watch(supabaseInitializerProvider);
  if (!initializer.isInitialized) {
    return PendingSupabaseSessionManager();
  }
  return SupabaseAuthSessionManager(Supabase.instance.client);
});

final supabaseExceptionMapperProvider = Provider<SupabaseExceptionMapper>((
  ref,
) {
  return SupabaseExceptionMapper(ref.watch(appLoggerProvider));
});

/// Auth / DB / Storage facades — repository wiring lands in a later milestone.
final supabaseAuthDataSourceProvider = Provider<SupabaseAuthDataSource>((ref) {
  return SupabaseAuthDataSourceImpl(ref.watch(supabaseClientProvider));
});

final supabaseDatabaseProvider = Provider<SupabaseDatabase>((ref) {
  throw UnimplementedError(
    'SupabaseDatabase is not wired yet. '
    'Use supabaseClientProvider.from(...) for interim access.',
  );
});

final supabaseStorageProvider = Provider<SupabaseStorage>((ref) {
  throw UnimplementedError(
    'SupabaseStorage is not wired yet. '
    'Use supabaseClientProvider.storage for interim access.',
  );
});

/// Loads URL + publishable/anon key from `--dart-define` or dotenv.
SupabaseConfig loadSupabaseConfig(AppEnvironment environment) {
  const definedUrl = String.fromEnvironment('SUPABASE_URL');
  const definedAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  const definedPublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  const definedLogs = String.fromEnvironment('ENABLE_NETWORK_LOGS');

  final url = definedUrl.isNotEmpty
      ? definedUrl
      : dotenv.get('SUPABASE_URL', fallback: '');

  final anonFromDefine = definedAnonKey.isNotEmpty
      ? definedAnonKey
      : definedPublishableKey;
  final anonFromEnv = dotenv.get('SUPABASE_ANON_KEY', fallback: '').isNotEmpty
      ? dotenv.get('SUPABASE_ANON_KEY', fallback: '')
      : dotenv.get('SUPABASE_PUBLISHABLE_KEY', fallback: '');

  final anonKey = anonFromDefine.isNotEmpty ? anonFromDefine : anonFromEnv;

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
