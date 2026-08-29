import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../models/plus_cosmetics.dart';
import '../models/user.dart';
import '../utils/board_tab_bus.dart';
import '../utils/helpers.dart';
import '../utils/main_tab_bus.dart';
import 'analytics_service.dart';
import 'avatar_service.dart';

class AuthService extends ChangeNotifier {
  AuthService();

  static const _profileTimeout = Duration(seconds: 6);

  final _client = Supabase.instance.client;

  User? _currentUser;
  String? _pendingEmail;
  bool _awaitingEmailConfirmation = false;
  bool _ready = false;

  /// Bumped on sign-out / intentional session invalidation so in-flight
  /// hydrates cannot resurrect [_currentUser] after logout.
  int _hydrateGeneration = 0;

  /// Skips auth-listener hydrate during same-user password re-check.
  bool _suppressAuthHydrate = false;

  /// Set when the profile row has `is_disabled` so login() can explain why.
  bool _accountDisabled = false;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get needsEmailVerification => _awaitingEmailConfirmation;
  bool get isReady => _ready;
  String? get pendingVerificationCode => null;
  String? get pendingEmail => _pendingEmail;

  /// Forces listeners to rebuild (e.g. after a prefs-only gate change).
  void pingListeners() => notifyListeners();

  Future<void> initialize() async {
    try {
      final session = _client.auth.currentSession;
      if (session != null) {
        await _hydrateSession(session);
      }
    } finally {
      _ready = true;
      notifyListeners();
    }

    _client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedOut || session == null) {
        _hydrateGeneration++;
        _currentUser = null;
        resetMainTabBus();
        resetBoardTabBus();
        notifyListeners();
        return;
      }

      if (_suppressAuthHydrate) return;

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.userUpdated) {
        await _hydrateSession(session);
      }
    });
  }

  /// Loads the profile row; on any failure still admits the user via session.
  Future<void> _hydrateSession(Session session) async {
    final gen = ++_hydrateGeneration;
    final userId = session.user.id;
    try {
      await _loadProfile(userId).timeout(_profileTimeout);
    } on TimeoutException {
      debugPrint('Profile load timed out — using session fallback');
    } catch (e) {
      debugPrint('Profile hydrate failed: $e');
    }

    // Logout (or a newer hydrate) won the race — do not restore user.
    if (gen != _hydrateGeneration) return;
    if (_client.auth.currentSession?.user.id != userId) return;

    _currentUser ??= _userFromSession(session);
    notifyListeners();
  }

  /// Re-fetches the signed-in profile (used before onboarding save).
  Future<void> reloadOwnProfile() async {
    final session = _client.auth.currentSession;
    if (session == null) return;
    await _loadProfile(session.user.id).timeout(_profileTimeout);
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

  Future<Map<String, dynamic>?> _fetchOwnProfileRow(String userId) async {
    try {
      final rows = await _client.rpc('get_own_profile');
      if (rows is List && rows.isNotEmpty) {
        return Map<String, dynamic>.from(rows.first as Map);
      }
    } catch (e) {
      debugPrint('get_own_profile RPC unavailable: $e');
    }

    // Fallback when v16 RPC is missing. Omit email — column grants hide it.
    return await _client
        .from('profiles')
        .select(
          'id, login, status, avatar_url, avatar_emoji, profile_wallpaper_id, '
          'custom_wallpaper_url, birthday, created_at, updated_at, last_seen_at, '
          'is_bot, dev_status, skills, experience_level, github_url, portfolio_url, city, '
          'avatar_frame, nick_color, is_plus, plus_until',
        )
        .eq('id', userId)
        .maybeSingle();
  }

  Future<void> _loadProfile(String userId) async {
    try {
      var row = await _fetchOwnProfileRow(userId);

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

        row = await _fetchOwnProfileRow(userId);
        if (row == null) return;
      }

      if (row['is_disabled'] == true) {
        _accountDisabled = true;
        _currentUser = null;
        _hydrateGeneration++;
        notifyListeners();
        unawaited(_client.auth.signOut());
        return;
      }

      final parsed = User.fromProfileRow(row);
      final sessionEmail = _client.auth.currentUser?.email ?? '';
      _currentUser = parsed.email.isEmpty && sessionEmail.isNotEmpty
          ? parsed.copyWith(email: sessionEmail)
          : parsed;

      _awaitingEmailConfirmation = false;
      _pendingEmail = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load profile: $e');
    }
  }

  /// Confirms the current user's password without treating auth events as a
  /// fresh login (avoids hydrate races / session thrash on web).
  Future<bool> verifyPassword(String password) async {
    final email = (_currentUser?.email.isNotEmpty == true)
        ? _currentUser!.email
        : (_client.auth.currentUser?.email ?? '');
    if (email.isEmpty) return false;

    _suppressAuthHydrate = true;
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response.session != null;
    } on AuthException {
      return false;
    } finally {
      _suppressAuthHydrate = false;
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
        await _hydrateSession(response.session!);
        if (_currentUser == null) {
          return 'Аккаунт создан, но профиль не загрузился. Войдите снова.';
        }
        await AnalyticsService.instance.track('register');
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

      final session = response.session;
      if (response.user == null || session == null) {
        return 'Не удалось войти';
      }

      await _hydrateSession(session);

      if (_accountDisabled) {
        _accountDisabled = false;
        return 'Этот аккаунт заблокирован';
      }

      final current = _currentUser;
      if (current == null) {
        return 'Вход прошёл, но профиль не загрузился. Проверьте сеть и попробуйте ещё раз.';
      }

      // Email+password already authenticate the account. A mistyped login used
      // to sign the user back out with no clear path forward — only warn.
      if (current.login.toLowerCase() != trimmedLogin.toLowerCase()) {
        debugPrint(
          'Login field "$trimmedLogin" differs from profile "${current.login}" — allowing email sign-in',
        );
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
    _hydrateGeneration++;
    _currentUser = null;
    resetMainTabBus();
    resetBoardTabBus();
    notifyListeners();
    await _client.auth.signOut();
  }

  /// Deletes auth user via SECURITY DEFINER RPC. Returns an error message on
  /// failure — never pretends success after a partial profile-only wipe.
  Future<String?> deleteAccount() async {
    final user = _currentUser;
    if (user == null) return 'Пользователь не авторизован';

    try {
      try {
        await AvatarService.deleteAvatar(user.login);
      } catch (_) {}
      await _client.rpc('delete_own_account');
      _hydrateGeneration++;
      _currentUser = null;
      resetMainTabBus();
      resetBoardTabBus();
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('deleteAccount error: $e');
      return 'Не удалось удалить аккаунт. Попробуйте позже.';
    }
  }

  Future<void> updateProfile(User updated) async {
    try {
      await _patchProfile(updated.toProfileUpdate());
      _currentUser = updated;
      notifyListeners();
    } catch (e) {
      debugPrint('updateProfile failed: $e');
      rethrow;
    }
  }

  Future<void> _patchProfile(Map<String, dynamic> fields) async {
    final user = _currentUser;
    if (user == null) {
      throw StateError('not signed in');
    }
    await _client
        .from('profiles')
        .update(fields)
        .eq('id', user.id)
        .timeout(const Duration(seconds: 12));
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

  /// Saves the developer card (job-search status, stack, level, links, city).
  Future<String?> updateDeveloperCard({
    required DevStatus devStatus,
    required List<String> skills,
    required ExperienceLevel? experienceLevel,
    required String? githubUrl,
    required String? portfolioUrl,
    required String? city,
  }) async {
    final user = _currentUser;
    if (user == null) return 'Пользователь не авторизован';

    try {
      final github = _blankToNull(githubUrl);
      final portfolio = _blankToNull(portfolioUrl);
      final cityValue = _blankToNull(city);
      await _client.from('profiles').update({
        'dev_status': devStatus.dbValue,
        'skills': skills,
        'experience_level': experienceLevel?.dbValue,
        'github_url': github,
        'portfolio_url': portfolio,
        'city': cityValue,
      }).eq('id', user.id).timeout(const Duration(seconds: 12));
      _currentUser = user.copyWith(
        devStatus: devStatus,
        skills: skills,
        experienceLevel: experienceLevel,
        clearExperienceLevel: experienceLevel == null,
        githubUrl: github ?? '',
        portfolioUrl: portfolio ?? '',
        city: cityValue ?? '',
      );
      notifyListeners();
      await AnalyticsService.instance.track('dev_card_save', {
        'status': devStatus.dbValue,
        'skills': skills.length,
      });
      return null;
    } catch (e) {
      debugPrint('updateDeveloperCard failed: $e');
      return 'Не удалось сохранить карточку разработчика';
    }
  }

  Future<String?> updateBirthday(DateTime? birthday) async {
    final user = _currentUser;
    if (user == null) return 'Пользователь не авторизован';
    try {
      await _patchProfile({
        'birthday': birthday?.toIso8601String().split('T').first,
      });
      _currentUser = birthday == null
          ? user.copyWith(clearBirthday: true)
          : user.copyWith(birthday: birthday);
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('updateBirthday failed: $e');
      return 'Не удалось сохранить дату рождения';
    }
  }

  Future<String?> updateAvatarBytes(Uint8List bytes) async {
    final user = _currentUser;
    if (user == null) return 'Пользователь не авторизован';

    try {
      final savedPath = await AvatarService.saveAvatarBytes(
        login: user.login,
        bytes: bytes,
      );
      await _patchProfile({'avatar_url': savedPath});
      _currentUser = user.copyWith(avatarPath: savedPath);
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('updateAvatarBytes failed: $e');
      return 'Не удалось сохранить аватар';
    }
  }

  Future<void> removeAvatar() async {
    final user = _currentUser;
    if (user == null) return;
    await AvatarService.deleteAvatar(user.login);
    await _patchProfile({'avatar_url': null});
    _currentUser = user.copyWith(clearAvatar: true);
    notifyListeners();
  }

  /// Sets an emoji as the avatar (removes the uploaded photo, if any).
  Future<String?> updateAvatarEmoji(String emoji) async {
    final user = _currentUser;
    if (user == null) return 'Пользователь не авторизован';

    try {
      try {
        await AvatarService.deleteAvatar(user.login);
      } catch (_) {}
      await _patchProfile({
        'avatar_emoji': emoji,
        'avatar_url': null,
      });
      _currentUser = user.copyWith(avatarEmoji: emoji, clearAvatar: true);
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('updateAvatarEmoji failed: $e');
      return 'Не удалось сохранить аватар';
    }
  }

  Future<String?> updateAvatarFrame(AvatarFrameId frame) async {
    final user = _currentUser;
    if (user == null) return 'Пользователь не авторизован';
    if (!user.isPlus && frame != AvatarFrameId.none) {
      return 'Нужна подписка Murkot Plus';
    }
    try {
      await _patchProfile({'avatar_frame': frame.dbValue});
      _currentUser = user.copyWith(avatarFrame: frame);
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('updateAvatarFrame failed: $e');
      return 'Не удалось сохранить рамку';
    }
  }

  Future<String?> updateNickColor(String? colorId) async {
    final user = _currentUser;
    if (user == null) return 'Пользователь не авторизован';
    if (!user.isPlus && colorId != null) {
      return 'Нужна подписка Murkot Plus';
    }
    try {
      await _patchProfile({'nick_color': colorId});
      _currentUser = colorId == null
          ? user.copyWith(clearNickColor: true)
          : user.copyWith(nickColorId: colorId);
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('updateNickColor failed: $e');
      return 'Не удалось сохранить цвет ника';
    }
  }

  Future<void> refreshPlusFromServer() async {
    final user = _currentUser;
    if (user == null) return;
    final row = await _fetchOwnProfileRow(user.id);
    if (row == null) return;
    final parsed = User.fromProfileRow(row);
    _currentUser = user.copyWith(
      isPlus: parsed.isPlus,
      plusUntil: parsed.plusUntil,
      avatarFrame: parsed.avatarFrame,
      nickColorId: parsed.nickColorId,
      clearPlusUntil: parsed.plusUntil == null,
      clearNickColor: parsed.nickColorId == null,
    );
    notifyListeners();
  }

  Future<String?> updateCustomWallpaperBytes(Uint8List bytes) async {
    final user = _currentUser;
    if (user == null) return 'Пользователь не авторизован';

    try {
      final savedPath = await AvatarService.saveAvatarBytes(
        login: user.login,
        bytes: bytes,
        suffix: 'wallpaper',
      );
      await _patchProfile({'custom_wallpaper_url': savedPath});
      _currentUser = user.copyWith(customWallpaperPath: savedPath);
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('updateCustomWallpaperBytes failed: $e');
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

    try {
      await _patchProfile({'status': trimmed});
      _currentUser = user.copyWith(status: trimmed);
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('updateStatus failed: $e');
      return 'Не удалось сохранить статус';
    }
  }

  Future<void> updateWallpaper(String wallpaperId) async {
    final user = _currentUser;
    if (user == null) return;
    await _patchProfile({
      'profile_wallpaper_id': wallpaperId,
      'custom_wallpaper_url': null,
    });
    _currentUser =
        user.copyWith(profileWallpaperId: wallpaperId, clearCustomWallpaper: true);
    notifyListeners();
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

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
