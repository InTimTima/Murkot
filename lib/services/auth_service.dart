import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../utils/helpers.dart';
import 'avatar_service.dart';
import 'chat_service.dart';

class AuthService extends ChangeNotifier {
  AuthService(this._prefs) {
    _loadSession();
  }

  static const _sessionKey = 'current_user';
  static const _usersKey = 'registered_users';
  static const _pendingCodeKey = 'pending_verification_code';
  static const _pendingUserKey = 'pending_verification_user';

  final SharedPreferences _prefs;

  User? _currentUser;
  User? _pendingUser;
  String? _pendingVerificationCode;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get needsEmailVerification => _pendingUser != null;
  String? get pendingVerificationCode => _pendingVerificationCode;

  bool verifyPassword(String password) {
    final user = _currentUser;
    if (user == null) return false;
    return _prefs.getString('pwd_${user.login}') == password;
  }

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
      (key, value) => MapEntry(key, User.fromJson(value as Map<String, dynamic>)),
    );
  }

  Future<void> _saveUsers(Map<String, User> users) async {
    await _prefs.setString(_usersKey, jsonEncode(
      users.map((key, user) => MapEntry(key, user.toJson())),
    ));
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

    for (final user in users.values) {
      if (user.email.toLowerCase() == trimmedEmail.toLowerCase()) {
        return 'Почта уже используется';
      }
    }

    users[trimmedLogin] = User(
      login: trimmedLogin,
      email: trimmedEmail,
      status: 'В сети',
      avatarEmoji: pickRandomEmoji(),
    );
    await _saveUsers(users);
    await _saveCredentials(trimmedLogin, password);
    await _saveSession(users[trimmedLogin]);
    return null;
  }

  Future<String?> login({
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
    final user = users[trimmedLogin];
    if (user == null) return 'Пользователь не найден';

    if (user.email.toLowerCase() != trimmedEmail.toLowerCase()) {
      return 'Почта не совпадает с аккаунтом';
    }

    if (_prefs.getString('pwd_$trimmedLogin') != password) {
      return 'Неверный пароль';
    }

    final code = generateVerificationCode();
    _pendingUser = user;
    _pendingVerificationCode = code;
    await _prefs.setString(_pendingCodeKey, code);
    await _prefs.setString(_pendingUserKey, jsonEncode(user.toJson()));
    notifyListeners();
    return null;
  }

  Future<String?> verifyEmailCode(String code) async {
    if (_pendingUser == null || _pendingVerificationCode == null) {
      return 'Нет ожидающей верификации';
    }
    if (code.trim() != _pendingVerificationCode) {
      return 'Неверный код подтверждения';
    }

    await _saveSession(_pendingUser);
    _pendingUser = null;
    _pendingVerificationCode = null;
    await _prefs.remove(_pendingCodeKey);
    await _prefs.remove(_pendingUserKey);
    notifyListeners();
    return null;
  }

  void cancelVerification() {
    _pendingUser = null;
    _pendingVerificationCode = null;
    _prefs.remove(_pendingCodeKey);
    _prefs.remove(_pendingUserKey);
    notifyListeners();
  }

  Future<void> logout() => _saveSession(null);

  Future<void> deleteAccount() async {
    final user = _currentUser;
    if (user == null) return;

    final users = _loadUsers();
    users.remove(user.login);
    await _saveUsers(users);
    await _prefs.remove('pwd_${user.login}');
    await AvatarService.deleteAvatar(user.login);
    await _saveSession(null);
  }

  Future<void> updateProfile(User updated) async {
    final users = _loadUsers();
    final oldLogin = _currentUser?.login;
    if (oldLogin != null && oldLogin != updated.login) {
      users.remove(oldLogin);
      final password = _prefs.getString('pwd_$oldLogin');
      if (password != null) {
        await _prefs.setString('pwd_${updated.login}', password);
        await _prefs.remove('pwd_$oldLogin');
      }
    }
    users[updated.login] = updated;
    await _saveUsers(users);
    await _saveSession(updated);
  }

  Future<String?> changeLogin(String newLogin) async {
    final user = _currentUser;
    if (user == null) return 'Пользователь не авторизован';

    final trimmed = newLogin.trim();
    if (trimmed.isEmpty) return 'Введите имя';
    if (trimmed == user.login) return null;

    if (_loadUsers().containsKey(trimmed)) {
      return 'Это имя уже занято';
    }

    await updateProfile(user.copyWith(login: trimmed));
    return null;
  }

  Future<String?> changeEmail(String newEmail, String password) async {
    final user = _currentUser;
    if (user == null) return 'Пользователь не авторизован';

    if (!verifyPassword(password)) return 'Неверный пароль';

    final trimmed = newEmail.trim();
    if (!trimmed.contains('@')) return 'Введите корректную почту';

    for (final u in _loadUsers().values) {
      if (u.login != user.login &&
          u.email.toLowerCase() == trimmed.toLowerCase()) {
        return 'Почта уже используется';
      }
    }

    await updateProfile(user.copyWith(email: trimmed));
    return null;
  }

  Future<void> updateBirthday(DateTime? birthday) async {
    final user = _currentUser;
    if (user == null) return;
    await updateProfile(user.copyWith(birthday: birthday));
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

  Future<String?> updateCustomWallpaper(String sourcePath) async {
    final user = _currentUser;
    if (user == null) return 'Пользователь не авторизован';

    try {
      final savedPath = await AvatarService.saveAvatar(
        '${user.login}_wallpaper',
        sourcePath,
      );
      await updateProfile(user.copyWith(customWallpaperPath: savedPath));
      return null;
    } catch (e) {
      return 'Не удалось сохранить обои';
    }
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

  Future<void> updateWallpaper(String wallpaperId) async {
    final user = _currentUser;
    if (user == null) return;
    await updateProfile(
      user.copyWith(profileWallpaperId: wallpaperId, clearCustomWallpaper: true),
    );
  }

  Future<void> _saveCredentials(String login, String password) async {
    await _prefs.setString('pwd_$login', password);
  }
}
