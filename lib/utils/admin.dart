/// Client-side hint for the admin UI. Real access is always checked
/// by `is_app_admin()` on the server.
bool isMurkotAdminLogin(String? login) {
  if (login == null || login.isEmpty) return false;
  final lower = login.toLowerCase();
  return lower == 'tima' || lower == 'hex';
}
