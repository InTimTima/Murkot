import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BlacklistService extends ChangeNotifier {
  BlacklistService({
    required String userId,
    required String userLogin,
  })  : _userId = userId,
        _userLogin = userLogin;

  final String _userId;
  final String _userLogin;
  final _client = Supabase.instance.client;

  List<String> _blockedUsers = [];

  List<String> get blockedUsers => List.unmodifiable(_blockedUsers);

  bool isBlocked(String login) {
    final key = login.trim().toLowerCase();
    if (key.isEmpty) return false;
    return _blockedUsers.any((u) => u.toLowerCase() == key);
  }

  Future<void> initialize() async {
    final rows = await _client
        .from('blocked_users')
        .select('blocked_login')
        .eq('blocker_id', _userId);

    _blockedUsers = (rows as List)
        .map((e) => e['blocked_login'] as String)
        .where((login) => login.trim().isNotEmpty)
        .toList();
    notifyListeners();
  }

  Future<void> blockUser(String login) async {
    final trimmed = login.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.toLowerCase() == _userLogin.toLowerCase()) return;
    if (isBlocked(trimmed)) return;

    try {
      await _client.from('blocked_users').upsert({
        'blocker_id': _userId,
        'blocked_login': trimmed,
      });

      _blockedUsers = [..._blockedUsers, trimmed];
      notifyListeners();
    } catch (e) {
      debugPrint('blockUser failed: $e');
      rethrow;
    }
  }

  Future<void> unblockUser(String login) async {
    final trimmed = login.trim();
    if (trimmed.isEmpty) return;

    try {
      // Match case-insensitively against stored rows.
      final match = _blockedUsers.cast<String?>().firstWhere(
            (u) => u!.toLowerCase() == trimmed.toLowerCase(),
            orElse: () => trimmed,
          )!;

      await _client
          .from('blocked_users')
          .delete()
          .eq('blocker_id', _userId)
          .eq('blocked_login', match);

      _blockedUsers = _blockedUsers
          .where((u) => u.toLowerCase() != trimmed.toLowerCase())
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('unblockUser failed: $e');
      rethrow;
    }
  }
}
