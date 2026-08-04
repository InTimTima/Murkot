import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/voice_recording.dart';

final _recorder = AudioRecorder();
DateTime? _startedAt;

Future<bool> startVoiceRecordingImpl() async {
  if (!await _recorder.hasPermission()) return false;
  final dir = await getTemporaryDirectory();
  final path =
      '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
  await _recorder.start(
    const RecordConfig(encoder: AudioEncoder.aacLc),
    path: path,
  );
  _startedAt = DateTime.now();
  return true;
}

Future<VoiceRecording?> stopVoiceRecordingImpl() async {
  final path = await _recorder.stop();
  final started = _startedAt;
  _startedAt = null;
  if (path == null) return null;

  final bytes = await File(path).readAsBytes();
  if (bytes.isEmpty) return null;
  final durationMs = started == null
      ? 0
      : DateTime.now().difference(started).inMilliseconds;
  return VoiceRecording(
    bytes: Uint8List.fromList(bytes),
    mimeType: 'audio/mp4',
    durationMs: durationMs,
    fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
  );
}

Future<void> cancelVoiceRecordingImpl() async {
  if (await _recorder.isRecording()) {
    await _recorder.stop();
  }
  _startedAt = null;
}
