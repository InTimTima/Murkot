import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class AvatarService {
  static final _client = Supabase.instance.client;

  static Future<String> saveAvatar(String login, String sourcePath) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Not authenticated');
    }

    final file = File(sourcePath);
    final bytes = await file.readAsBytes();
    final path = '$userId/${login}_avatar.jpg';

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

  static Future<void> deleteAvatar(String login) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final path = '$userId/${login}_avatar.jpg';
    try {
      await _client.storage.from('avatars').remove([path]);
    } catch (_) {
      // Ignore missing objects.
    }
  }
}
