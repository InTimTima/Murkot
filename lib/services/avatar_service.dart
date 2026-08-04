import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class AvatarService {
  static final _client = Supabase.instance.client;

  static Future<String> saveAvatarBytes({
    required String login,
    required Uint8List bytes,
    String suffix = 'avatar',
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Not authenticated');
    }
    if (bytes.isEmpty) {
      throw StateError('Empty image');
    }

    final path = '$userId/${login}_$suffix.jpg';

    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    final publicUrl = _client.storage.from('avatars').getPublicUrl(path);
    return '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  static Future<void> deleteAvatar(String login, {String suffix = 'avatar'}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final path = '$userId/${login}_$suffix.jpg';
    try {
      await _client.storage.from('avatars').remove([path]);
    } catch (_) {
      // Ignore missing objects.
    }
  }
}
