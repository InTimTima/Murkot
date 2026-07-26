import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BlacklistService extends ChangeNotifier {
  BlacklistService(this._prefs, this._userLogin) {
    _load();
  }

  static const _keyPrefix = 'blacklist';

  final SharedPreferences _prefs;
  final String _userLogin;

  List<String> _blockedUsers = [];

  List<String> get blockedUsers => List.unmodifiable(_blockedUsers);

  bool isBlocked(String login) => _blockedUsers.contains(login);

  Future<void> blockUser(String login) async {
    if (login == _userLogin || _blockedUsers.contains(login)) return;
    _blockedUsers.add(login);
    await _save();
    notifyListeners();
  }

  Future<void> unblockUser(String login) async {
    _blockedUsers.remove(login);
    await _save();
    notifyListeners();
  }

  void _load() {
    final raw = _prefs.getString('${_keyPrefix}_$_userLogin');
    if (raw == null) return;
    _blockedUsers = (jsonDecode(raw) as List<dynamic>).cast<String>();
  }

  Future<void> _save() async {
    await _prefs.setString(
      '${_keyPrefix}_$_userLogin',
      jsonEncode(_blockedUsers),
    );
  }
}
