import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { ru, en }

enum AppTextSize { small, normal, large }

class SettingsService extends ChangeNotifier {
  SettingsService(this._prefs) {
    _themeMode = ThemeMode.values[_prefs.getInt(_themeKey) ?? 0];
    _language = AppLanguage.values[_prefs.getInt(_languageKey) ?? 0];
    _textSize = AppTextSize.values[_prefs.getInt(_textSizeKey) ?? 1];
  }

  static const _themeKey = 'settings_theme';
  static const _languageKey = 'settings_language';
  static const _textSizeKey = 'settings_text_size';

  final SharedPreferences _prefs;

  late ThemeMode _themeMode;
  late AppLanguage _language;
  late AppTextSize _textSize;

  ThemeMode get themeMode => _themeMode;
  AppLanguage get language => _language;
  AppTextSize get textSize => _textSize;

  Locale get locale =>
      _language == AppLanguage.ru ? const Locale('ru') : const Locale('en');

  double get textScaleFactor => switch (_textSize) {
        AppTextSize.small => 0.9,
        AppTextSize.normal => 1.0,
        AppTextSize.large => 1.15,
      };

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt(_themeKey, mode.index);
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    _language = language;
    await _prefs.setInt(_languageKey, language.index);
    notifyListeners();
  }

  Future<void> setTextSize(AppTextSize size) async {
    _textSize = size;
    await _prefs.setInt(_textSizeKey, size.index);
    notifyListeners();
  }
}
