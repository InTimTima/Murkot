import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import 'avatar_service.dart';

class AuthService extends ChangeNotifier {
  AuthService(this._prefs) {
    _loadSession();
  }

  static const _sessionKey = 'current_user';
  static const _usersKey = 'registered_users';

  final SharedPreferences _prefs;

  User? _currentUser;
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  void _loadSession() {
    final raw = _prefs.getString(_sessionKey);
    if (raw == null) return;
    _currentUser = User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Map<String, User> _loadUsers() {
    final raw = _prefs.getString(_usersKey);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map(
      (key, value) => MapEntry(
        key,
        User.fromJson(value as Map<String, dynamic>),
      ),
    );
  }

  Future<void> _saveUsers(Map<String, User> users) async {
    final encoded = users.map((key, user) => MapEntry(key, user.toJson()));
    await _prefs.setString(_usersKey, jsonEncode(encoded));
  }

  Future<void> _saveSession(User? user) async {
    if (user == null) {
      await _prefs.remove(_sessionKey);
    } else {
      await _prefs.setString(_sessionKey, jsonEncode(user.toJson()));
    }
    _currentUser = user;
    notifyListeners();
  }

  Future<String?> register({
    required String login,
    required String password,
    required String email,
  }) async {
    final trimmedLogin = login.trim();
    final trimmedEmail = email.trim();

    if (trimmedLogin.isEmpty || password.isEmpty) {
      return 'Введите логин и пароль';
    }
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      return 'Введите корректную почту';
    }

    final users = _loadUsers();
    if (users.containsKey(trimmedLogin)) {
      return 'Пользователь с таким логином уже существует';
    }

    users[trimmedLogin] = User(
      login: trimmedLogin,
      email: trimmedEmail,
      status: 'В сети',
    );
    await _saveUsers(users);
    await _saveCredentials(trimmedLogin, password);
    await _saveSession(users[trimmedLogin]);
    return null;
  }

  Future<String?> login({
    required String login,
    required String password,
  }) async {
    final trimmedLogin = login.trim();
    if (trimmedLogin.isEmpty || password.isEmpty) {
      return 'Введите логин и пароль';
    }

    final users = _loadUsers();
    final user = users[trimmedLogin];
    if (user == null) {
      return 'Пользователь не найден';
    }

    final storedPassword = _prefs.getString('pwd_$trimmedLogin');
    if (storedPassword != password) {
      return 'Неверный пароль';
    }

    await _saveSession(user);
    return null;
  }

  Future<void> logout() => _saveSession(null);

  Future<void> updateProfile(User updated) async {
    final users = _loadUsers();
    users[updated.login] = updated;
    await _saveUsers(users);
    await _saveSession(updated);
  }

  Future<String?> updateAvatar(String sourcePath) async {
    final user = _currentUser;
    if (user == null) return 'Пользователь не авторизован';

    try {
      final savedPath = await AvatarService.saveAvatar(user.login, sourcePath);
      await updateProfile(user.copyWith(avatarPath: savedPath));
      return null;
    } catch (e) {
      return 'Не удалось сохранить аватар';
    }
  }

  Future<void> removeAvatar() async {
    final user = _currentUser;
    if (user == null) return;

    await AvatarService.deleteAvatar(user.login);
    await updateProfile(user.copyWith(clearAvatar: true));
  }

  Future<String?> updateStatus(String status) async {
    final user = _currentUser;
    if (user == null) return 'Пользователь не авторизован';

    final trimmed = status.trim();
    if (trimmed.length > 120) {
      return 'Статус не может быть длиннее 120 символов';
    }

    if (trimmed == user.status) return null;

    await updateProfile(user.copyWith(status: trimmed));
    return null;
  }

  Future<void> _saveCredentials(String login, String password) async {
    await _prefs.setString('pwd_$login', password);
  }
}
