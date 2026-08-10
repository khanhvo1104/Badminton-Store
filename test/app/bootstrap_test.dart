import 'package:base_project/app/bootstrap.dart';
import 'package:base_project/app/configuration_error_app.dart';
import 'package:base_project/core/config/app_environment.dart';
import 'package:base_project/core/config/environment_provider.dart';
import 'package:base_project/core/storage/storage_providers.dart';
import 'package:base_project/core/supabase/supabase_config.dart';
import 'package:base_project/core/supabase/supabase_initializer.dart';
import 'package:base_project/core/supabase/supabase_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-secret placeholders — never real credentials.
const _placeholderUrl = 'https://example.invalid.supabase.co';
const _placeholderKey = 'test-publishable-key-not-a-secret';

class _FakeSupabaseInitializer implements SupabaseInitializer {
  int initializeCallCount = 0;
  SupabaseConfig? lastConfig;
  Exception? throwOnInitialize;
  bool _initialized = false;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize(SupabaseConfig config) async {
    initializeCallCount += 1;
    lastConfig = config;
    final error = throwOnInitialize;
    if (error != null) {
      throw error;
    }
    _initialized = true;
  }
}

class _SentinelInitException implements Exception {
  const _SentinelInitException();

  @override
  String toString() => 'SentinelInitException';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late _FakeSupabaseInitializer initializer;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    initializer = _FakeSupabaseInitializer();
  });

  group('buildBootstrapRoot unconfigured', () {
    test(
      'missing URL returns ConfigurationErrorApp and skips initialize',
      () async {
        final root = await buildBootstrapRoot(
          config: const SupabaseConfig(
            environment: AppEnvironment.development,
            url: '',
            anonKey: _placeholderKey,
          ),
          environment: AppEnvironment.development,
          preferences: preferences,
          initializer: initializer,
          child: const SizedBox.shrink(),
        );

        expect(root, isA<ConfigurationErrorApp>());
        expect(initializer.initializeCallCount, 0);
      },
    );

    test(
      'missing key returns ConfigurationErrorApp and skips initialize',
      () async {
        final root = await buildBootstrapRoot(
          config: const SupabaseConfig(
            environment: AppEnvironment.development,
            url: _placeholderUrl,
            anonKey: '',
          ),
          environment: AppEnvironment.development,
          preferences: preferences,
          initializer: initializer,
          child: const SizedBox.shrink(),
        );

        expect(root, isA<ConfigurationErrorApp>());
        expect(initializer.initializeCallCount, 0);
      },
    );

    test(
      'missing URL and key returns ConfigurationErrorApp and skips initialize',
      () async {
        final root = await buildBootstrapRoot(
          config: const SupabaseConfig(
            environment: AppEnvironment.development,
            url: '',
            anonKey: '',
          ),
          environment: AppEnvironment.development,
          preferences: preferences,
          initializer: initializer,
          child: const SizedBox.shrink(),
        );

        expect(root, isA<ConfigurationErrorApp>());
        expect(initializer.initializeCallCount, 0);
      },
    );

    testWidgets(
      'unconfigured path does not mount ProviderScope or normal child',
      (tester) async {
        const childKey = Key('normal-child');
        final root = await buildBootstrapRoot(
          config: const SupabaseConfig(
            environment: AppEnvironment.development,
            url: '',
            anonKey: '',
          ),
          environment: AppEnvironment.development,
          preferences: preferences,
          initializer: initializer,
          child: const SizedBox(key: childKey),
        );

        await tester.pumpWidget(root);

        expect(find.byType(ConfigurationErrorApp), findsOneWidget);
        expect(find.byType(ProviderScope), findsNothing);
        expect(find.byKey(childKey), findsNothing);
        expect(initializer.initializeCallCount, 0);
      },
    );
  });

  group('buildBootstrapRoot configured', () {
    testWidgets('initializes once and mounts ProviderScope with overrides', (
      tester,
    ) async {
      const config = SupabaseConfig(
        environment: AppEnvironment.staging,
        url: _placeholderUrl,
        anonKey: _placeholderKey,
      );

      final root = await buildBootstrapRoot(
        config: config,
        environment: AppEnvironment.staging,
        preferences: preferences,
        initializer: initializer,
        child: Consumer(
          builder: (context, ref, _) {
            final env = ref.watch(appEnvironmentProvider);
            final prefs = ref.watch(sharedPreferencesProvider);
            final init = ref.watch(supabaseInitializerProvider);
            return Text(
              'env=${env.name};'
              'prefs=${identical(prefs, preferences)};'
              'init=${identical(init, initializer)}',
            );
          },
        ),
      );

      expect(root, isA<ProviderScope>());
      expect(initializer.initializeCallCount, 1);
      expect(identical(initializer.lastConfig, config), isTrue);

      await tester.pumpWidget(
        Directionality(textDirection: TextDirection.ltr, child: root),
      );

      expect(find.byType(ConfigurationErrorApp), findsNothing);
      expect(find.text('env=staging;prefs=true;init=true'), findsOneWidget);
    });

    test(
      'initialization failure propagates and is not a configuration error',
      () async {
        const sentinel = _SentinelInitException();
        initializer.throwOnInitialize = sentinel;

        await expectLater(
          () => buildBootstrapRoot(
            config: const SupabaseConfig(
              environment: AppEnvironment.development,
              url: _placeholderUrl,
              anonKey: _placeholderKey,
            ),
            environment: AppEnvironment.development,
            preferences: preferences,
            initializer: initializer,
            child: const SizedBox.shrink(),
          ),
          throwsA(same(sentinel)),
        );

        expect(initializer.initializeCallCount, 1);
      },
    );
  });
}
