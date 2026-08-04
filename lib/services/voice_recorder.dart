import '../models/voice_recording.dart';
import 'voice_recorder_stub.dart'
    if (dart.library.html) 'voice_recorder_web.dart' as impl;

export '../models/voice_recording.dart';

Future<bool> startVoiceRecording() => impl.startVoiceRecordingImpl();

Future<VoiceRecording?> stopVoiceRecording() => impl.stopVoiceRecordingImpl();

Future<void> cancelVoiceRecording() => impl.cancelVoiceRecordingImpl();
