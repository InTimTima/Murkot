import 'dart:convert';

class MediaPayload {
  const MediaPayload({
    required this.url,
    required this.name,
    this.durationMs,
    this.isCircle = false,
  });

  final String url;
  final String name;
  final int? durationMs;
  final bool isCircle;

  String encode() => jsonEncode({
        'url': url,
        'name': name,
        if (durationMs != null) 'durationMs': durationMs,
        if (isCircle) 'circle': true,
      });

  static MediaPayload? tryParse(String content) {
    final trimmed = content.trim();
    if (trimmed.startsWith('{') && trimmed.contains('"url"')) {
      try {
        final map = jsonDecode(trimmed) as Map<String, dynamic>;
        final url = map['url'] as String?;
        final name = map['name'] as String? ?? 'file';
        if (url != null && url.isNotEmpty) {
          return MediaPayload(
            url: url,
            name: name,
            durationMs: map['durationMs'] as int?,
            isCircle: map['circle'] == true,
          );
        }
      } catch (_) {}
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return MediaPayload(url: trimmed, name: trimmed.split('/').last);
    }
    return null;
  }

  static bool looksLikeMedia(String content) => tryParse(content) != null;
}
