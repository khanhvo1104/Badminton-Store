import 'package:shared_preferences/shared_preferences.dart';

/// Abstraction over SharedPreferences for non-sensitive preferences.
abstract interface class PreferencesService {
  Future<String?> getString(String key);

  Future<bool> setString(String key, String value);

  Future<bool> remove(String key);
}

class PreferencesServiceImpl implements PreferencesService {
  PreferencesServiceImpl(this._preferences);

  final SharedPreferences _preferences;

  @override
  Future<String?> getString(String key) async => _preferences.getString(key);

  @override
  Future<bool> setString(String key, String value) {
    return _preferences.setString(key, value);
  }

  @override
  Future<bool> remove(String key) => _preferences.remove(key);
}

class FakePreferencesService implements PreferencesService {
  final Map<String, String> _values = {};

  @override
  Future<String?> getString(String key) async => _values[key];

  @override
  Future<bool> setString(String key, String value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _values.remove(key);
    return true;
  }
}
