import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class AvatarService {
  static final _client = Supabase.instance.client;

  static bool isGifBytes(Uint8List bytes) {
    if (bytes.length < 6) return false;
    return bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38 &&
        (bytes[4] == 0x39 || bytes[4] == 0x37) &&
        bytes[5] == 0x61;
  }

  static Future<String> saveAvatarBytes({
    required String login,
    required Uint8List bytes,
    String suffix = 'avatar',
    String? contentType,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Not authenticated');
    }
    if (bytes.isEmpty) {
      throw StateError('Empty image');
    }

    final gif = contentType == 'image/gif' || isGifBytes(bytes);
    final ext = gif ? 'gif' : 'jpg';
    final mime = gif ? 'image/gif' : (contentType ?? 'image/jpeg');
    final path = '$userId/${login}_$suffix.$ext';

    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: mime,
          ),
        );

    final publicUrl = _client.storage.from('avatars').getPublicUrl(path);
    return '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  static Future<void> deleteAvatar(String login, {String suffix = 'avatar'}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    for (final ext in ['jpg', 'gif', 'png', 'webp']) {
      final path = '$userId/${login}_$suffix.$ext';
      try {
        await _client.storage.from('avatars').remove([path]);
      } catch (_) {}
    }
  }
}
