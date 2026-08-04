import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../models/user.dart';
import '../utils/helpers.dart';
import 'avatar_service.dart';

class AuthService extends ChangeNotifier {
  AuthService();

  static const _profileTimeout = Duration(seconds: 6);

  final _client = Supabase.instance.client;

  User? _currentUser;
  String? _pendingEmail;
  bool _awaitingEmailConfirmation = false;
  bool _ready = false;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get needsEmailVerification => _awaitingEmailConfirmation;
  bool get isReady => _ready;
  String? get pendingVerificationCode => null;
  String? get pendingEmail => _pendingEmail;

  Future<void> initialize() async {
    try {
      final session = _client.auth.currentSession;
      if (session != null) {
        try {
          await _loadProfile(session.user.id).timeout(_profileTimeout);
        } on TimeoutException {
          debugPrint('Profile load timed out — using session fallback');
          _currentUser ??= _userFromSession(session);
        }
        // If the network failed entirely, still let the user into the shell.
        _currentUser ??= _userFromSession(session);
      }
    } finally {
      _ready = true;
      notifyListeners();
    }

    _client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedOut || session == null) {
        _currentUser = null;
        notifyListeners();
        return;
      }

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.userUpdated) {
        try {
          await _loadProfile(session.user.id).timeout(_profileTimeout);
        } on TimeoutException {
          debugPrint('Profile refresh timed out');
          _currentUser ??= _userFromSession(session);
          notifyListeners();
        }
      }
    });
  }

  User _userFromSession(Session session) {
    final authUser = session.user;
    final login = (authUser.userMetadata?['login'] as String?) ??
        authUser.email?.split('@').first ??
        'user';
    final emoji = (authUser.userMetadata?['avatar_emoji'] as String?) ??
        pickRandomEmoji();
    return User(
      id: authUser.id,
      login: login,
      email: authUser.email ?? '',
      avatarEmoji: emoji,
      status: 'В сети',
    );
  }

  Future<void> _loadProfile(String userId) async {
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (row == null) {
        final authUser = _client.auth.currentUser;
        if (authUser == null) return;

        final login = (authUser.userMetadata?['login'] as String?) ??
            authUser.email?.split('@').first ??
            'user';
        final emoji =
            (authUser.userMetadata?['avatar_emoji'] as String?) ??
            pickRandomEmoji();

        await _client.from('profiles').upsert({
          'id': authUser.id,
          'login': login,
          'email': authUser.email ?? '',
          'avatar_emoji': emoji,
          'status': 'В сети',
        });

        final created = await _client
            .from('profiles')
            .select()
            .eq('id', userId)
            .single();
        _currentUser = User.fromProfileRow(created);
      } else {
        _currentUser = User.fromProfileRow(row);
      }

      _awaitingEmailConfirmation = false;
      _pendingEmail = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load profile: $e');
    }
  }

  Future<bool> verifyPassword(String password) async {
    final email = _currentUser?.email;
    if (email == null || email.isEmpty) return false;

    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response.session != null;
    } on AuthException {
      return false;
    }
  }

  Future<String?> register({
    required String login,
    required String password,
    required String email,
  }) async {
    final trimmedLogin = login.trim();
    final trimmedEmail = email.trim().toLowerCase();

    if (trimmedLogin.isEmpty || password.isEmpty) {
      return 'Введите логин и пароль';
    }
    if (password.length < 6) {
      return 'Пароль должен быть не короче 6 символов';
    }
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      return 'Введите корректную почту';
    }

    try {
      final available = await _client.rpc(
        'is_login_available',
        params: {'desired_login': trimmedLogin},
      );
      if (available == false) {
        return 'Пользователь с таким логином уже существует';
      }

      final emoji = pickRandomEmoji();
      final response = await _client.auth.signUp(
        email: trimmedEmail,
        password: password,
        data: {
          'login': trimmedLogin,
          'avatar_emoji': emoji,
        },
      );

      if (response.user == null) {
        return 'Не удалось создать аккаунт';
      }

      if (response.session != null) {
        await _loadProfile(response.user!.id);
        return null;
      }

      _pendingEmail = trimmedEmail;
      _awaitingEmailConfirmation = true;
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      return _mapAuthError(e);
    } catch (e) {
      return 'Ошибка регистрации: $e';
    }
  }

  Future<String?> login({
    required String login,
    required String password,
    required String email,
  }) async {
    final trimmedLogin = login.trim();
    final trimmedEmail = email.trim().toLowerCase();

    if (trimmedLogin.isEmpty || password.isEmpty) {
      return 'Введите логин и пароль';
    }
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      return 'Введите корректную почту';
    }

    try {
      final response = await _client.auth.signInWithPassword(
        email: trimmedEmail,
        password: password,
      );

      final user = response.user;
      if (user == null || response.session == null) {
        return 'Не удалось войти';
      }

      await _loadProfile(user.id);

      final current = _currentUser;
      if (current != null &&
          current.login.toLowerCase() != trimmedLogin.toLowerCase()) {
        await _client.auth.signOut();
        _currentUser = null;
        notifyListeners();
        return 'Логин не совпадает с аккаунтом';
      }

      return null;
    } on AuthException catch (e) {
      return _mapAuthError(e);
    } catch (e) {
      return 'Ошибка входа: $e';
    }
  }

  Future<String?> verifyEmailCode(String code) async {
    final email = _pendingEmail;
    if (email == null) return 'Нет ожидающей верификации';

    try {
      final response = await _client.auth.verifyOTP(
        email: email,
        token: code.trim(),
        type: OtpType.signup,
      );

      if (response.session == null || response.user == null) {
        return 'Неверный код подтверждения';
      }

      await _loadProfile(response.user!.id);
      return null;
    } on AuthException catch (e) {
      return _mapAuthError(e);
    } catch (e) {
      return 'Не удалось подтвердить почту';
    }
  }

  Future<String?> resendVerificationEmail() async {
    final email = _pendingEmail;
    if (email == null) return 'Нет ожидающей верификации';

    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      return null;
    } on AuthException catch (e) {
      return _mapAuthError(e);
    } catch (e) {
      return 'Не удалось отправить письмо';
    }
  }

  void cancelVerification() {
    _pendingEmail = null;
    _awaitingEmailConfirmation = false;
    notifyListeners();
  }

  Future<void> logout() async {
    await _client.auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    final user = _currentUser;
    if (user == null) return;

    try {
      await AvatarService.deleteAvatar(user.login);
      await _client.rpc('delete_own_account');
    } catch (e) {
      debugPrint('deleteAccount error: $e');
      await _client.from('profiles').delete().eq('id', user.id);
      await _client.auth.signOut();
    }

    _currentUser = null;
    notifyListeners();
  }

  Future<void> updateProfile(User updated) async {
    await _client.from('profiles').update(updated.toProfileUpdate()).eq(
          'id',
          updated.id,
        );
    _currentUser = updated;
    notifyListeners();
  }

  Future<String?> changeLogin(String newLogin) async {
    final user = _currentUser;
    if (user == null) return 'Пользователь не авторизован';

    final trimmed = newLogin.trim();
    if (trimmed.isEmpty) return 'Введите имя';
    if (trimmed == user.login) return null;

    try {
      final available = await _client.rpc(
        'is_login_available',
        params: {'desired_login': trimmed},
      );
      if (available == false) return 'Это имя уже занято';

      await updateProfile(user.copyWith(login: trimmed));
      await _client.auth.updateUser(
        UserAttributes(data: {'login': trimmed}),
      );
      return null;
    } catch (e) {
      return 'Не удалось сменить имя';
    }
  }

  Future<String?> changeEmail(String newEmail, String password) async {
    final user = _currentUser;
    if (user == null) return 'Пользователь не авторизован';

    if (!await verifyPassword(password)) return 'Неверный пароль';

    final trimmed = newEmail.trim().toLowerCase();
    if (!trimmed.contains('@')) return 'Введите корректную почту';

    try {
      await _client.auth.updateUser(UserAttributes(email: trimmed));
      await updateProfile(user.copyWith(email: trimmed));
      return null;
    } on AuthException catch (e) {
      return _mapAuthError(e);
    } catch (e) {
      return 'Не удалось сменить почту';
    }
  }

  Future<void> updateBirthday(DateTime? birthday) async {
    final user = _currentUser;
    if (user == null) return;
    await updateProfile(
      birthday == null
          ? user.copyWith(clearBirthday: true)
          : user.copyWith(birthday: birthday),
    );
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

  String _mapAuthError(AuthException e) {
    final message = e.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Неверный email или пароль';
    }
    if (message.contains('user already registered')) {
      return 'Почта уже используется';
    }
    if (message.contains('email not confirmed')) {
      return 'Подтвердите почту перед входом';
    }
    if (message.contains('password')) {
      return 'Пароль слишком слабый (минимум 6 символов)';
    }
    if (message.contains('otp') || message.contains('token')) {
      return 'Неверный или просроченный код';
    }
    return e.message;
  }
}
