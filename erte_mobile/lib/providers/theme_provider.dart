import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('SharedPreferences belum diinisialisasi.'),
);

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) {
    return ThemeModeController(ref.watch(sharedPreferencesProvider));
  },
);

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._preferences)
    : super(_readThemeMode(_preferences.getString('themeMode')));

  final SharedPreferences _preferences;

  static ThemeMode _readThemeMode(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setThemeMode(ThemeMode value) async {
    await _preferences.setString('themeMode', value.name);
    state = value;
  }
}
