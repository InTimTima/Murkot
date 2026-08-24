import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class FeedbackLetter {
  const FeedbackLetter({
    required this.id,
    required this.authorId,
    required this.authorLogin,
    required this.text,
    this.photoUrl,
    required this.createdAt,
    this.avatarUrl,
    this.avatarEmoji,
  });

  final String id;
  final String authorId;
  final String authorLogin;
  final String text;
  final String? photoUrl;
  final DateTime createdAt;
  final String? avatarUrl;
  final String? avatarEmoji;

  factory FeedbackLetter.fromRow(Map<String, dynamic> r) => FeedbackLetter(
        id: r['id'] as String,
        authorId: r['author_id'] as String,
        authorLogin: r['author_login'] as String? ?? '?',
        text: r['text'] as String? ?? '',
        photoUrl: r['photo_url'] as String?,
        createdAt: DateTime.tryParse(r['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        avatarUrl: r['avatar_url'] as String?,
        avatarEmoji: r['avatar_emoji'] as String?,
      );
}

class FeedbackService {
  Future<String?> submit({required String text, String? photoUrl}) async {
    try {
      await Supabase.instance.client.rpc('submit_feedback', params: {
        'p_text': text,
        'p_photo_url': photoUrl,
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<List<FeedbackLetter>> listForAdmin() async {
    final rows = await Supabase.instance.client.rpc('admin_list_feedback');
    return (rows as List).map((r) => FeedbackLetter.fromRow(Map<String, dynamic>.from(r as Map))).toList();
  }

  Future<String?> uploadPhoto({required String login, required List<int> bytes}) async {
    try {
      final path = 'feedback/${DateTime.now().millisecondsSinceEpoch}_${login}.jpg';
      await Supabase.instance.client.storage.from('chat-media').uploadBinary(path, Uint8List.fromList(bytes), fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
      return Supabase.instance.client.storage.from('chat-media').getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }
}
