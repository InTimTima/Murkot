import 'package:flutter/foundation.dart';

/// Pending `/@login` deep link consumed after auth + MainScreen boot.
final ValueNotifier<String?> pendingProfileLogin = ValueNotifier<String?>(null);

final _loginRe = RegExp(r'^[a-zA-Z0-9_]{2,32}$');

bool isValidProfileLogin(String login) => _loginRe.hasMatch(login);

/// Reads `/@login`, `/u/login`, `/profile/login`, or hash equivalents from [uri].
String? extractProfileLogin(Uri uri) {
  final fromFragment = _loginFromPath(
    uri.fragment.isEmpty
        ? ''
        : (uri.fragment.startsWith('/') ? uri.fragment : '/${uri.fragment}'),
  );
  if (fromFragment != null) return fromFragment;
  return _loginFromPath(uri.path);
}

String? _loginFromPath(String path) {
  if (path.isEmpty) return null;
  final segs =
      path.split('/').where((s) => s.isNotEmpty && s != 'index.html').toList();
  for (final seg in segs) {
    if (seg.startsWith('@') && seg.length > 1) {
      final login = seg.substring(1);
      if (isValidProfileLogin(login)) return login;
    }
  }
  for (var i = 0; i < segs.length - 1; i++) {
    final key = segs[i].toLowerCase();
    if (key == 'u' || key == 'profile' || key == 'p') {
      final raw = segs[i + 1];
      final login = raw.startsWith('@') ? raw.substring(1) : raw;
      if (isValidProfileLogin(login)) return login;
    }
  }
  return null;
}

/// Captures the browser URL once at startup.
void captureInitialProfileDeepLink() {
  if (!kIsWeb) return;
  final login = extractProfileLogin(Uri.base);
  if (login != null) {
    pendingProfileLogin.value = login;
  }
}

/// Public share URL for a profile (`…/@login`).
String buildPublicProfileUrl(String login) {
  final clean = login.trim().replaceFirst(RegExp(r'^@'), '');
  if (kIsWeb) {
    final base = Uri.base;
    final segs = base.path
        .split('/')
        .where(
          (s) =>
              s.isNotEmpty &&
              s != 'index.html' &&
              !s.startsWith('@'),
        )
        .toList();
    // Drop /u|profile|p/<login> tails if present.
    if (segs.length >= 2) {
      final prev = segs[segs.length - 2].toLowerCase();
      if (prev == 'u' || prev == 'profile' || prev == 'p') {
        segs.removeRange(segs.length - 2, segs.length);
      }
    }
    final prefix = segs.isEmpty ? '' : '/${segs.join('/')}';
    return base
        .replace(
          path: '$prefix/@$clean',
          query: '',
          fragment: '',
        )
        .toString();
  }
  return 'https://quannxxii.github.io/Murkot/@$clean';
}

/// Takes and clears [pendingProfileLogin] if set.
String? consumePendingProfileLogin() {
  final login = pendingProfileLogin.value;
  if (login == null) return null;
  pendingProfileLogin.value = null;
  return login;
}
