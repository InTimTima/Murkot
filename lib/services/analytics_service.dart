import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lightweight product analytics (Supabase `track_event` + debug log).
class AnalyticsService {
  AnalyticsService._();
  static final instance = AnalyticsService._();

  final _client = Supabase.instance.client;

  Future<void> track(String name, [Map<String, dynamic>? props]) async {
    debugPrint('analytics:$name ${props ?? const {}}');
    try {
      if (_client.auth.currentUser == null) return;
      await _client.rpc(
        'track_event',
        params: {
          'p_name': name,
          'p_props': props ?? <String, dynamic>{},
        },
      );
    } catch (e) {
      debugPrint('analytics track failed: $e');
    }
  }
}
