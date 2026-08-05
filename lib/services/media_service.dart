import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class MediaService {
  static final _client = Supabase.instance.client;

  /// Bucket limit configured in features_v3.sql.
  static const int maxUploadBytes = 50 * 1024 * 1024;

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
    if (bytes.isEmpty) {
      throw StateError('Файл пустой');
    }
    if (bytes.lengthInBytes > maxUploadBytes) {
      final mb = (bytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(1);
      throw StateError('Файл слишком большой ($mb МБ, максимум 50 МБ)');
    }

    final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final path =
        '$userId/$conversationId/${DateTime.now().millisecondsSinceEpoch}_$safeName';

    Future<void> upload() => _client.storage.from('chat-media').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: contentType,
          ),
        );

    try {
      await upload();
    } on StorageException catch (e) {
      // Expired auth token: refresh the session and retry once.
      final unauthorized = e.statusCode == '401' ||
          e.statusCode == '403' ||
          e.message.toLowerCase().contains('jwt');
      if (!unauthorized) rethrow;
      await _client.auth.refreshSession();
      await upload();
    }

    return _client.storage.from('chat-media').getPublicUrl(path);
  }
}
