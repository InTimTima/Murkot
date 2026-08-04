import 'dart:convert';
import 'dart:js_interop';

import '../models/voice_recording.dart';

@JS('murkotVoiceStart')
external JSPromise<JSBoolean> _murkotVoiceStart();

@JS('murkotVoiceStop')
external JSPromise<JSAny?> _murkotVoiceStop();

@JS('murkotVoiceCancel')
external JSPromise<JSAny?> _murkotVoiceCancel();

Future<bool> startVoiceRecordingImpl() async {
  try {
    final ok = await _murkotVoiceStart().toDart;
    return ok.toDart;
  } catch (_) {
    return false;
  }
}

Future<VoiceRecording?> stopVoiceRecordingImpl() async {
  try {
    final result = await _murkotVoiceStop().toDart;
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
    await _murkotVoiceCancel().toDart;
  } catch (_) {}
}
