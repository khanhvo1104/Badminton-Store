import 'package:base_project/core/storage/preferences_service.dart';
import 'package:base_project/core/storage/secure_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageServiceImpl();
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in bootstrap',
  );
});

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  return PreferencesServiceImpl(ref.watch(sharedPreferencesProvider));
});
