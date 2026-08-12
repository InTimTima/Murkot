import 'package:flutter/foundation.dart';

import 'invite_deep_link_stub.dart'
    if (dart.library.html) 'invite_deep_link_web.dart' as stash;

/// Pending `/i/<token>` invite deep link consumed after MainScreen boot.
final ValueNotifier<String?> pendingInviteToken = ValueNotifier<String?>(null);

final _tokenRe = RegExp(r'^[a-fA-F0-9]{32,128}$');

bool isValidInviteToken(String token) => _tokenRe.hasMatch(token);

/// Reads `/i/<token>` or `/join/<token>` (path or hash).
String? extractInviteToken(Uri uri) {
  final fromFragment = _tokenFromPath(
    uri.fragment.isEmpty
        ? ''
        : (uri.fragment.startsWith('/') ? uri.fragment : '/${uri.fragment}'),
  );
  if (fromFragment != null) return fromFragment;
  return _tokenFromPath(uri.path);
}

String? _tokenFromPath(String path) {
  if (path.isEmpty) return null;
  final segs =
      path.split('/').where((s) => s.isNotEmpty && s != 'index.html').toList();
  for (var i = 0; i < segs.length - 1; i++) {
    final key = segs[i].toLowerCase();
    if (key == 'i' || key == 'join') {
      final token = segs[i + 1];
      if (isValidInviteToken(token)) return token;
    }
  }
  return null;
}

/// Accepts a raw token or a full invite URL / path.
String? normalizeInviteInput(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (isValidInviteToken(trimmed)) return trimmed;

  final asUri = Uri.tryParse(trimmed);
  if (asUri != null && (asUri.hasScheme || trimmed.contains('/'))) {
    final fromUri = extractInviteToken(asUri);
    if (fromUri != null) return fromUri;
  }

  final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
  return extractInviteToken(Uri(path: path));
}

void captureInitialInviteDeepLink() {
  if (!kIsWeb) return;
  final fromUri = extractInviteToken(Uri.base);
  final fromStash = stash.consumeStashedInviteToken();
  final token = fromUri ?? fromStash;
  if (token != null && isValidInviteToken(token)) {
    pendingInviteToken.value = token;
  }
}

String buildPublicInviteUrl(String token) {
  final clean = token.trim();
  if (kIsWeb) {
    final base = Uri.base;
    final segs = base.path
        .split('/')
        .where(
          (s) =>
              s.isNotEmpty &&
              s != 'index.html' &&
              !s.startsWith('@') &&
              s.toLowerCase() != 'i' &&
              s.toLowerCase() != 'join',
        )
        .toList();
    // Drop trailing token if path was /i/<token>
    if (segs.isNotEmpty && isValidInviteToken(segs.last)) {
      segs.removeLast();
    }
    final keepPrefix = segs.length == 1 && segs.first == 'Murkot';
    final prefix = keepPrefix ? '/Murkot' : '';
    return base
        .replace(
          path: '$prefix/i/$clean',
          query: '',
          fragment: '',
        )
        .toString();
  }
  return 'https://murkot.vercel.app/i/$clean';
}

String? consumePendingInviteToken() {
  final token = pendingInviteToken.value;
  if (token == null) return null;
  pendingInviteToken.value = null;
  return token;
}
