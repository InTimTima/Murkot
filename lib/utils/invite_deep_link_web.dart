import 'dart:html' as html;

/// Reads `/i/<token>` stashed by `web/index.html` before Flutter rewrites the URL.
String? consumeStashedInviteToken() {
  final token = html.window.sessionStorage['murkot_invite_token'];
  if (token == null || token.isEmpty) return null;
  html.window.sessionStorage.remove('murkot_invite_token');
  return token;
}
