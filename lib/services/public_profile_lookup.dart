import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_preview.dart';

const _previewColumns =
    'id, login, status, avatar_emoji, avatar_url, is_bot, city';

/// Loads public cards for listing/project authors when the nested
/// `author:profiles` embed is empty (guest / anon RLS).
Future<Map<String, UserPreview>> loadPublicPreviews(
  Iterable<String> ids,
) async {
  final unique = ids.where((id) => id.isNotEmpty).toSet().toList();
  if (unique.isEmpty) return const {};

  final client = Supabase.instance.client;
  try {
    final rows = await client
        .from('public_profiles')
        .select(_previewColumns)
        .inFilter('id', unique);
    return _mapPreviews(rows);
  } catch (e) {
    debugPrint('public_profiles lookup failed: $e');
    try {
      final rows = await client
          .from('profiles')
          .select(_previewColumns)
          .inFilter('id', unique);
      return _mapPreviews(rows);
    } catch (fallback) {
      debugPrint('profiles lookup failed: $fallback');
      return const {};
    }
  }
}

Map<String, UserPreview> _mapPreviews(dynamic rows) {
  if (rows is! List) return const {};
  final map = <String, UserPreview>{};
  for (final raw in rows) {
    if (raw is! Map) continue;
    final preview = UserPreview.fromRow(Map<String, dynamic>.from(raw));
    map[preview.id] = preview;
  }
  return map;
}
