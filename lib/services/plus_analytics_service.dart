import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/plus_cosmetics.dart';

class ProfileVisitor {
  const ProfileVisitor({
    required this.id,
    required this.login,
    this.avatarUrl,
    this.avatarEmoji,
    this.avatarFrame = AvatarFrameId.none,
    this.nickColorId,
    required this.at,
    this.source,
  });

  final String id;
  final String login;
  final String? avatarUrl;
  final String? avatarEmoji;
  final AvatarFrameId avatarFrame;
  final String? nickColorId;
  final DateTime at;
  final String? source;
}

/// Profile views + contact saves for Murkot Plus.
class PlusAnalyticsService {
  PlusAnalyticsService();

  final _client = Supabase.instance.client;

  Future<void> recordView(String login) async {
    try {
      await _client.rpc('record_profile_view', params: {'p_login': login});
    } catch (e) {
      debugPrint('record_profile_view failed: $e');
    }
  }

  Future<void> recordContactSave(String login, {String source = 'chat'}) async {
    try {
      await _client.rpc(
        'record_contact_save',
        params: {'p_login': login, 'p_source': source},
      );
    } catch (e) {
      debugPrint('record_contact_save failed: $e');
    }
  }

  Future<List<ProfileVisitor>> listViews() async {
    try {
      final rows = await _client.rpc('list_my_profile_views', params: {'p_limit': 40});
      if (rows is! List) return const [];
      return [
        for (final raw in rows)
          if (raw is Map)
            ProfileVisitor(
              id: raw['viewer_id'] as String,
              login: raw['login'] as String? ?? '?',
              avatarUrl: raw['avatar_url'] as String?,
              avatarEmoji: raw['avatar_emoji'] as String?,
              avatarFrame: AvatarFrameId.fromDb(raw['avatar_frame'] as String?),
              nickColorId: raw['nick_color'] as String?,
              at: DateTime.tryParse('${raw['viewed_at']}')?.toLocal() ??
                  DateTime.now(),
            ),
      ];
    } catch (e) {
      debugPrint('list_my_profile_views failed: $e');
      return const [];
    }
  }

  Future<List<ProfileVisitor>> listContactSaves() async {
    try {
      final rows =
          await _client.rpc('list_my_contact_saves', params: {'p_limit': 40});
      if (rows is! List) return const [];
      return [
        for (final raw in rows)
          if (raw is Map)
            ProfileVisitor(
              id: raw['saver_id'] as String,
              login: raw['login'] as String? ?? '?',
              avatarUrl: raw['avatar_url'] as String?,
              avatarEmoji: raw['avatar_emoji'] as String?,
              avatarFrame: AvatarFrameId.fromDb(raw['avatar_frame'] as String?),
              nickColorId: raw['nick_color'] as String?,
              at: DateTime.tryParse('${raw['saved_at']}')?.toLocal() ??
                  DateTime.now(),
              source: raw['source'] as String?,
            ),
      ];
    } catch (e) {
      debugPrint('list_my_contact_saves failed: $e');
      return const [];
    }
  }

  Future<int> freeTopBoostsLeft() async {
    try {
      final n = await _client.rpc('free_top_boosts_left');
      return (n as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('free_top_boosts_left failed: $e');
      return 0;
    }
  }

  Future<bool> consumeFreeTopBoost(String listingId) async {
    try {
      final ok = await _client.rpc(
        'consume_free_top_boost',
        params: {'p_listing_id': listingId},
      );
      return ok == true;
    } catch (e) {
      debugPrint('consume_free_top_boost failed: $e');
      return false;
    }
  }
}
