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

  bool isBlocked(String login) => _blockedUsers.contains(login);

  Future<void> initialize() async {
    final rows = await _client
        .from('blocked_users')
        .select('blocked_login')
        .eq('blocker_id', _userId);

    _blockedUsers = (rows as List)
        .map((e) => e['blocked_login'] as String)
        .toList();
    notifyListeners();
  }

  Future<void> blockUser(String login) async {
    if (login == _userLogin || _blockedUsers.contains(login)) return;

    await _client.from('blocked_users').upsert({
      'blocker_id': _userId,
      'blocked_login': login,
    });

    _blockedUsers = [..._blockedUsers, login];
    notifyListeners();
  }

  Future<void> unblockUser(String login) async {
    await _client
        .from('blocked_users')
        .delete()
        .eq('blocker_id', _userId)
        .eq('blocked_login', login);

    _blockedUsers = _blockedUsers.where((u) => u != login).toList();
    notifyListeners();
  }
}
