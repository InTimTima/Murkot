import 'dart:convert';

/// Structured payload for [MessageType.system] messages.
/// Plain text content is still supported as a fallback.
class SystemPayload {
  const SystemPayload({
    required this.text,
    this.actorLogin,
    this.targetLogin,
    this.targetMessageId,
    this.targetPreview,
  });

  final String text;
  final String? actorLogin;
  final String? targetLogin;
  final String? targetMessageId;
  final String? targetPreview;

  Map<String, dynamic> toJson() => {
        'v': 1,
        'text': text,
        if (actorLogin != null) 'actor': actorLogin,
        if (targetLogin != null) 'target': targetLogin,
        if (targetMessageId != null) 'msgId': targetMessageId,
        if (targetPreview != null) 'preview': targetPreview,
      };

  String encode() => jsonEncode(toJson());

  static SystemPayload? tryParse(String content) {
    final trimmed = content.trim();
    if (!trimmed.startsWith('{')) {
      return SystemPayload(text: content);
    }
    try {
      final map = jsonDecode(trimmed) as Map<String, dynamic>;
      final text = map['text'] as String?;
      if (text == null || text.isEmpty) return SystemPayload(text: content);
      return SystemPayload(
        text: text,
        actorLogin: map['actor'] as String?,
        targetLogin: map['target'] as String?,
        targetMessageId: map['msgId'] as String?,
        targetPreview: map['preview'] as String?,
      );
    } catch (_) {
      return SystemPayload(text: content);
    }
  }
}
