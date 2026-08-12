import 'dart:html' as html;

/// Reads `/@login` stashed by `web/index.html` before Flutter rewrites the URL.
String? consumeStashedProfileLogin() {
  final login = html.window.sessionStorage['murkot_profile_login'];
  if (login == null || login.isEmpty) return null;
  html.window.sessionStorage.remove('murkot_profile_login');
  return login;
}
