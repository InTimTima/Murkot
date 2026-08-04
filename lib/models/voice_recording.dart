import 'dart:typed_data';

class VoiceRecording {
  const VoiceRecording({
    required this.bytes,
    required this.mimeType,
    required this.durationMs,
    required this.fileName,
  });

  final Uint8List bytes;
  final String mimeType;
  final int durationMs;
  final String fileName;
}
