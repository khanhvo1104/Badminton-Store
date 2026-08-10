import 'package:base_project/app/app.dart';
import 'package:base_project/app/configuration_error_app.dart';
import 'package:base_project/core/config/app_environment.dart';
import 'package:base_project/core/config/environment_provider.dart';
import 'package:base_project/core/logging/app_logger.dart';
import 'package:base_project/core/storage/storage_providers.dart';
import 'package:base_project/core/supabase/supabase_config.dart';
import 'package:base_project/core/supabase/supabase_initializer.dart';
import 'package:base_project/core/supabase/supabase_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> bootstrap(AppEnvironment environment) async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: environment.envFileName);

  final preferences = await SharedPreferences.getInstance();
  final startupLogger = AppLogger(enableDebugLogs: !kReleaseMode);

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    startupLogger.error(
      'Flutter error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    startupLogger.error(
      'Unhandled platform error',
      error: error,
      stackTrace: stack,
    );
    return true;
  };

  final supabaseConfig = loadSupabaseConfig(environment);
  final supabaseInitializer = FlutterSupabaseInitializer(startupLogger);

  final root = await buildBootstrapRoot(
    config: supabaseConfig,
    environment: environment,
    preferences: preferences,
    initializer: supabaseInitializer,
  );

  runApp(root);
}

/// Selects the startup root after [SupabaseConfig] is loaded.
///
/// Incomplete configuration returns [ConfigurationErrorApp] without initializing
/// Supabase or mounting [ProviderScope]. Valid configuration initializes once
/// and returns the normal provider graph. Initialization exceptions propagate.
@visibleForTesting
Future<Widget> buildBootstrapRoot({
  required SupabaseConfig config,
  required AppEnvironment environment,
  required SharedPreferences preferences,
  required SupabaseInitializer initializer,
  Widget child = const App(),
}) async {
  if (!config.isConfigured) {
    return const ConfigurationErrorApp();
  }

  await initializer.initialize(config);

  return ProviderScope(
    overrides: [
      appEnvironmentProvider.overrideWithValue(environment),
      sharedPreferencesProvider.overrideWithValue(preferences),
      supabaseInitializerProvider.overrideWithValue(initializer),
    ],
    child: child,
  );
}
