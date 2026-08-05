import 'package:flutter/material.dart';

/// Standalone startup screen shown when Supabase configuration is incomplete.
///
/// Independent of Riverpod, routing, authentication, and Supabase providers.
/// Does not display URL, key, or environment-file contents.
class ConfigurationErrorApp extends StatelessWidget {
  const ConfigurationErrorApp({super.key});

  static const String title = 'Application configuration unavailable';

  static const String guidance =
      'This build is missing required Supabase settings. Provide SUPABASE_URL '
      'and either SUPABASE_PUBLISHABLE_KEY or the legacy SUPABASE_ANON_KEY '
      'through your deployment or build configuration, then restart the app.';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 64,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.settings_suggest_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.error,
                            semanticLabel: 'Configuration error',
                          ),
                          const SizedBox(height: 24),
                          Semantics(
                            header: true,
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              guidance,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
