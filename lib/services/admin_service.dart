import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/admin.dart';

class AdminOverview {
  const AdminOverview({
    required this.usersTotal,
    required this.usersOnline,
    required this.usersToday,
    required this.usersWeek,
    required this.usersDisabled,
    required this.listingsTotal,
    required this.listingsActive,
    required this.projectsTotal,
    required this.conversationsTotal,
    required this.conversationsDirect,
    required this.conversationsGroup,
    required this.conversationsChannel,
    required this.messagesToday,
    required this.messagesTotal,
    required this.reportsOpen,
    required this.swipesToday,
  });

  final int usersTotal;
  final int usersOnline;
  final int usersToday;
  final int usersWeek;
  final int usersDisabled;
  final int listingsTotal;
  final int listingsActive;
  final int projectsTotal;
  final int conversationsTotal;
  final int conversationsDirect;
  final int conversationsGroup;
  final int conversationsChannel;
  final int messagesToday;
  final int messagesTotal;
  final int reportsOpen;
  final int swipesToday;

  factory AdminOverview.fromJson(Map<String, dynamic> json) {
    return AdminOverview(
      usersTotal: _asInt(json['users_total']),
      usersOnline: _asInt(json['users_online']),
      usersToday: _asInt(json['users_today']),
      usersWeek: _asInt(json['users_week']),
      usersDisabled: _asInt(json['users_disabled']),
      listingsTotal: _asInt(json['listings_total']),
      listingsActive: _asInt(json['listings_active']),
      projectsTotal: _asInt(json['projects_total']),
      conversationsTotal: _asInt(json['conversations_total']),
      conversationsDirect: _asInt(json['conversations_direct']),
      conversationsGroup: _asInt(json['conversations_group']),
      conversationsChannel: _asInt(json['conversations_channel']),
      messagesToday: _asInt(json['messages_today']),
      messagesTotal: _asInt(json['messages_total']),
      reportsOpen: _asInt(json['reports_open']),
      swipesToday: _asInt(json['swipes_today']),
    );
  }
}

class AdminUserRow {
  const AdminUserRow({
    required this.id,
    required this.login,
    this.avatarEmoji,
    this.avatarUrl,
    this.city,
    this.createdAt,
    this.lastSeenAt,
    this.isDisabled = false,
    this.isOnline = false,
    this.listingsActive = 0,
    this.listingsTotal = 0,
    this.isAdmin = false,
  });

  final String id;
  final String login;
  final String? avatarEmoji;
  final String? avatarUrl;
  final String? city;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;
  final bool isDisabled;
  final bool isOnline;
  final int listingsActive;
  final int listingsTotal;
  final bool isAdmin;

  factory AdminUserRow.fromRow(Map<String, dynamic> row) {
    return AdminUserRow(
      id: row['id'] as String,
      login: row['login'] as String? ?? '?',
      avatarEmoji: row['avatar_emoji'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      city: row['city'] as String?,
      createdAt: _asDate(row['created_at']),
      lastSeenAt: _asDate(row['last_seen_at']),
      isDisabled: row['is_disabled'] == true,
      isOnline: row['is_online'] == true,
      listingsActive: _asInt(row['listings_active']),
      listingsTotal: _asInt(row['listings_total']),
      isAdmin: row['is_admin'] == true,
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

class AdminService extends ChangeNotifier {
  final _client = Supabase.instance.client;

  bool? _isAdmin;
  bool _loading = false;
  String? _error;
  AdminOverview? _overview;
  List<AdminUserRow> _users = const [];
  String _query = '';
  bool _onlineOnly = false;

  bool? get isAdmin => _isAdmin;
  bool get isLoading => _loading;
  String? get error => _error;
  AdminOverview? get overview => _overview;
  List<AdminUserRow> get users => _users;
  String get query => _query;
  bool get onlineOnly => _onlineOnly;

  Future<bool> checkAdmin({String? login}) async {
    try {
      final result = await _client.rpc('is_app_admin');
      _isAdmin = result == true;
    } catch (e) {
      debugPrint('is_app_admin failed: $e');
      _isAdmin = isMurkotAdminLogin(login);
    }
    notifyListeners();
    return _isAdmin ?? false;
  }

  void setQuery(String value) {
    _query = value;
  }

  void setOnlineOnly(bool value) {
    if (_onlineOnly == value) return;
    _onlineOnly = value;
    notifyListeners();
    refreshUsers();
  }

  Future<void> refresh({String? login}) async {
    if (_isAdmin != true) {
      final ok = await checkAdmin(login: login);
      if (!ok) return;
    }
    await Future.wait([refreshOverview(), refreshUsers()]);
  }

  Future<void> refreshOverview() async {
    try {
      final result = await _client.rpc('admin_overview');
      final map = _asMap(result);
      if (map == null) {
        _overview = null;
        _error = 'empty overview';
      } else {
        _overview = AdminOverview.fromJson(map);
        _error = null;
      }
    } catch (e) {
      debugPrint('admin_overview failed: $e');
      _error = e.toString();
      _overview = null;
    }
    notifyListeners();
  }

  Future<void> refreshUsers() async {
    _loading = true;
    notifyListeners();
    try {
      final rows = await _client.rpc(
        'admin_list_users',
        params: {
          'p_query': _query.trim().isEmpty ? null : _query.trim(),
          'p_online_only': _onlineOnly,
          'p_limit': 60,
          'p_offset': 0,
        },
      );
      _users = (rows as List)
          .map((r) => AdminUserRow.fromRow(Map<String, dynamic>.from(r as Map)))
          .toList();
      if (_error != null && _error!.contains('admin_list_users')) {
        _error = null;
      }
    } catch (e) {
      debugPrint('admin_list_users failed: $e');
      _error = e.toString();
      _users = const [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> setUserDisabled({
    required String userId,
    required bool disabled,
  }) async {
    try {
      await _client.rpc(
        'admin_set_user_disabled',
        params: {
          'p_user_id': userId,
          'p_disabled': disabled,
        },
      );
      await refreshUsers();
      return null;
    } catch (e) {
      debugPrint('admin_set_user_disabled failed: $e');
      return e.toString();
    }
  }

  Future<String?> deactivateUserListings(String userId) async {
    try {
      await _client.rpc(
        'admin_deactivate_user_listings',
        params: {'p_user_id': userId},
      );
      await refreshUsers();
      return null;
    } catch (e) {
      debugPrint('admin_deactivate_user_listings failed: $e');
      return e.toString();
    }
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  if (value is List && value.isNotEmpty && value.first is Map) {
    return Map<String, dynamic>.from(value.first as Map);
  }
  return null;
}
