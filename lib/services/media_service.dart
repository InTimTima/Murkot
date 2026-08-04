import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class MediaService {
  static final _client = Supabase.instance.client;

  static Future<String> uploadChatMedia({
    required String conversationId,
    required Uint8List bytes,
    required String fileName,
    String contentType = 'application/octet-stream',
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Not authenticated');
    }

    final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final path =
        '$userId/$conversationId/${DateTime.now().millisecondsSinceEpoch}_$safeName';

    await _client.storage.from('chat-media').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: contentType,
          ),
        );

    return _client.storage.from('chat-media').getPublicUrl(path);
  }
}
