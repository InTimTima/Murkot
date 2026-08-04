import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import '../models/voice_recording.dart';

@JS('tujhVoiceStart')
external JSPromise<JSBoolean> _tujhVoiceStart();

@JS('tujhVoiceStop')
external JSPromise<JSAny?> _tujhVoiceStop();

@JS('tujhVoiceCancel')
external JSPromise<JSAny?> _tujhVoiceCancel();

Future<bool> startVoiceRecordingImpl() async {
  try {
    final ok = await _tujhVoiceStart().toDart;
    return ok.toDart;
  } catch (_) {
    return false;
  }
}

Future<VoiceRecording?> stopVoiceRecordingImpl() async {
  try {
    final result = await _tujhVoiceStop().toDart;
    if (result == null) return null;
    final map = result.dartify();
    if (map is! Map) return null;
    final base64 = map['base64'] as String?;
    final mimeType = map['mimeType'] as String? ?? 'audio/webm';
    final durationMs = (map['durationMs'] as num?)?.toInt() ?? 0;
    if (base64 == null || base64.isEmpty) return null;
    final bytes = base64Decode(base64);
    final ext = mimeType.contains('ogg')
        ? 'ogg'
        : mimeType.contains('mp4')
            ? 'm4a'
            : 'webm';
    return VoiceRecording(
      bytes: bytes,
      mimeType: mimeType,
      durationMs: durationMs,
      fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
  } catch (e) {
    // ignore: avoid_print
    print('Voice stop failed: $e');
    return null;
  }
}

Future<void> cancelVoiceRecordingImpl() async {
  try {
    await _tujhVoiceCancel().toDart;
  } catch (_) {}
}
