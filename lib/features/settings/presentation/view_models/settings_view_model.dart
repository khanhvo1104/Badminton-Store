import 'package:base_project/core/constants/storage_keys.dart';
import 'package:base_project/core/storage/storage_providers.dart';
import 'package:base_project/core/ui/glass/glass_quality.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class AppearanceSettings {
  const AppearanceSettings({
    this.themeMode = ThemeMode.system,
    this.glassQuality = GlassQuality.medium,
    this.reduceMotion = false,
    this.ambientAnimation = true,
  });

  final ThemeMode themeMode;
  final GlassQuality glassQuality;
  final bool reduceMotion;
  final bool ambientAnimation;

  AppearanceSettings copyWith({
    ThemeMode? themeMode,
    GlassQuality? glassQuality,
    bool? reduceMotion,
    bool? ambientAnimation,
  }) {
    return AppearanceSettings(
      themeMode: themeMode ?? this.themeMode,
      glassQuality: glassQuality ?? this.glassQuality,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      ambientAnimation: ambientAnimation ?? this.ambientAnimation,
    );
  }
}

class AppearanceSettingsNotifier extends StateNotifier<AppearanceSettings> {
  AppearanceSettingsNotifier(this._ref) : super(const AppearanceSettings()) {
    _ready = _restore();
  }

  final Ref _ref;
  late final Future<void> _ready;
  var _mutationEpoch = 0;

  Future<void> _restore() async {
    final prefs = _ref.read(preferencesServiceProvider);
    final theme = await prefs.getString(StorageKeys.themeMode);
    final quality = await prefs.getString(StorageKeys.glassQuality);
    final reduce = await prefs.getString(StorageKeys.reduceMotion);
    final ambient = await prefs.getString(StorageKeys.ambientAnimation);
    if (!mounted || _mutationEpoch > 0) {
      return;
    }

    state = AppearanceSettings(
      themeMode: switch (theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      glassQuality: GlassQuality.fromStorage(quality),
      reduceMotion: reduce == 'true',
      ambientAnimation: ambient != 'false',
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _ready;
    _mutationEpoch++;
    state = state.copyWith(themeMode: mode);
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _ref
        .read(preferencesServiceProvider)
        .setString(StorageKeys.themeMode, value);
  }

  Future<void> setGlassQuality(GlassQuality quality) async {
    await _ready;
    _mutationEpoch++;
    state = state.copyWith(glassQuality: quality);
    await _ref
        .read(preferencesServiceProvider)
        .setString(StorageKeys.glassQuality, quality.storageValue);
  }

  Future<void> setReduceMotion({required bool value}) async {
    await _ready;
    _mutationEpoch++;
    state = state.copyWith(reduceMotion: value);
    await _ref
        .read(preferencesServiceProvider)
        .setString(StorageKeys.reduceMotion, value.toString());
  }

  Future<void> setAmbientAnimation({required bool value}) async {
    await _ready;
    _mutationEpoch++;
    state = state.copyWith(ambientAnimation: value);
    await _ref
        .read(preferencesServiceProvider)
        .setString(StorageKeys.ambientAnimation, value.toString());
  }
}

final appearanceSettingsProvider =
    StateNotifierProvider<AppearanceSettingsNotifier, AppearanceSettings>(
      (ref) => AppearanceSettingsNotifier(ref),
    );

/// Backward-compatible alias used by App themeMode wiring.
final settingsViewModelProvider = Provider<ThemeMode>((ref) {
  return ref.watch(appearanceSettingsProvider.select((s) => s.themeMode));
});
