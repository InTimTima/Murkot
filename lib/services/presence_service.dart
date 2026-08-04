import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tracks online users via Supabase Realtime Presence + last_seen heartbeat.
class PresenceService extends ChangeNotifier {
  PresenceService({
    required String userId,
    required String userLogin,
  })  : _userId = userId,
        _userLogin = userLogin;

  final String _userId;
  final String _userLogin;
  final _client = Supabase.instance.client;

  RealtimeChannel? _channel;
  Timer? _heartbeat;
  final Set<String> _onlineLogins = {};
  final Map<String, DateTime> _lastSeenByLogin = {};

  Set<String> get onlineLogins => Set.unmodifiable(_onlineLogins);

  bool isOnline(String login) => _onlineLogins.contains(login);

  DateTime? lastSeenOf(String login) => _lastSeenByLogin[login];

  Future<void> initialize() async {
    await touchLastSeen();
    _subscribePresence();
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(touchLastSeen());
    });
  }

  Future<void> touchLastSeen() async {
    try {
      await _client.rpc('touch_last_seen');
      _lastSeenByLogin[_userLogin] = DateTime.now().toUtc();
    } catch (e) {
      debugPrint('touch_last_seen failed: $e');
    }
  }

  void seedLastSeen(Map<String, DateTime?> values) {
    for (final entry in values.entries) {
      final value = entry.value;
      if (value != null) {
        _lastSeenByLogin[entry.key] = value.toUtc();
      }
    }
    notifyListeners();
  }

  void _subscribePresence() {
    _channel?.unsubscribe();
    _channel = _client.channel(
      'online-users',
      opts: RealtimeChannelConfig(key: _userId),
    );

    _channel!
      ..onPresenceSync((_) {
        final state = _channel!.presenceState();
        final next = <String>{};
        for (final present in state) {
          for (final meta in present.presences) {
            final login = meta.payload['login'] as String?;
            if (login != null && login.isNotEmpty) {
              next.add(login);
              _lastSeenByLogin[login] = DateTime.now().toUtc();
            }
          }
        }
        _onlineLogins
          ..clear()
          ..addAll(next);
        notifyListeners();
      })
      ..subscribe((status, error) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await _channel!.track({
            'user_id': _userId,
            'login': _userLogin,
            'online_at': DateTime.now().toUtc().toIso8601String(),
          });
        } else if (error != null) {
          debugPrint('Presence subscribe error: $error');
        }
      });
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    unawaited(touchLastSeen());
    unawaited(_channel?.untrack() ?? Future.value());
    _channel?.unsubscribe();
    super.dispose();
  }
}
