import 'package:base_project/app/app.dart';
import 'package:base_project/core/config/app_environment.dart';
import 'package:base_project/core/config/environment_provider.dart';
import 'package:base_project/core/logging/app_logger.dart';
import 'package:base_project/core/storage/storage_providers.dart';
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
  await supabaseInitializer.initialize(supabaseConfig);

  runApp(
    ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(environment),
        sharedPreferencesProvider.overrideWithValue(preferences),
        supabaseInitializerProvider.overrideWithValue(supabaseInitializer),
      ],
      child: const App(),
    ),
  );
}
