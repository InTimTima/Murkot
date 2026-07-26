import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { ru, en }

enum AppTextSize { small, normal, large }

class PersonalizationKeys {
  static const online = 'online';
  static const offline = 'offline';
  static const typing = 'typing';
  static const chats = 'chats';
  static const groups = 'groups';
  static const channels = 'channels';
  static const createChat = 'createChat';
  static const createGroup = 'createGroup';
  static const createChannel = 'createChannel';
  static const message = 'message';
  static const info = 'info';
  static const profile = 'profile';
  static const settings = 'settings';
}

class SettingsService extends ChangeNotifier {
  SettingsService(this._prefs) {
    _themeMode = ThemeMode.values[_prefs.getInt(_themeKey) ?? 0];
    _language = AppLanguage.values[_prefs.getInt(_languageKey) ?? 0];
    _textSize = AppTextSize.values[_prefs.getInt(_textSizeKey) ?? 1];
    _loadPersonalization();
  }

  static const _themeKey = 'settings_theme';
  static const _languageKey = 'settings_language';
  static const _textSizeKey = 'settings_text_size';
  static const _personalizationKey = 'settings_personalization';

  final SharedPreferences _prefs;

  late ThemeMode _themeMode;
  late AppLanguage _language;
  late AppTextSize _textSize;
  Map<String, String> _personalization = {};

  ThemeMode get themeMode => _themeMode;
  AppLanguage get language => _language;
  AppTextSize get textSize => _textSize;
  Map<String, String> get personalization => Map.unmodifiable(_personalization);

  Locale get locale =>
      _language == AppLanguage.ru ? const Locale('ru') : const Locale('en');

  double get textScaleFactor => switch (_textSize) {
        AppTextSize.small => 0.9,
        AppTextSize.normal => 1.0,
        AppTextSize.large => 1.15,
      };

  String label(String key, String defaultValue) {
    final custom = _personalization[key]?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return defaultValue;
  }

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

  Future<void> setPersonalizationLabel(String key, String value) async {
    if (value.trim().isEmpty) {
      _personalization.remove(key);
    } else {
      _personalization[key] = value.trim();
    }
    await _prefs.setString(_personalizationKey, jsonEncode(_personalization));
    notifyListeners();
  }

  Future<void> resetPersonalization() async {
    _personalization.clear();
    await _prefs.remove(_personalizationKey);
    notifyListeners();
  }

  void _loadPersonalization() {
    final raw = _prefs.getString(_personalizationKey);
    if (raw == null) return;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _personalization = map.map((k, v) => MapEntry(k, v as String));
  }
}
