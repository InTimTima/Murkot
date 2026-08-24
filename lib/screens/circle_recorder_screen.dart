import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/brand_theme.dart';
import '../l10n/app_strings.dart';

class CircleRecording {
  const CircleRecording({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

/// In-app circular camera, Telegram-style, with gallery-camera fallback.
Future<CircleRecording?> recordCircleVideo(BuildContext context) {
  return Navigator.of(context).push<CircleRecording>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const CircleRecorderScreen(),
    ),
  );
}

class CircleRecorderScreen extends StatefulWidget {
  const CircleRecorderScreen({super.key});

  @override
  State<CircleRecorderScreen> createState() => _CircleRecorderScreenState();
}

class _CircleRecorderScreenState extends State<CircleRecorderScreen> {
  CameraController? _camera;
  String? _error;
  bool _recording = false;
  DateTime? _started;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'no-camera');
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: true,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _fallbackPick() async {
    final file = await ImagePicker().pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 60),
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    Navigator.pop(
      context,
      CircleRecording(bytes: bytes, name: file.name),
    );
  }

  Future<void> _toggleRecord() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) {
      await _fallbackPick();
      return;
    }
    if (_recording) {
      _ticker?.cancel();
      try {
        final file = await camera.stopVideoRecording();
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        Navigator.pop(
          context,
          CircleRecording(bytes: bytes, name: file.name),
        );
      } catch (e) {
        if (mounted) setState(() => _error = e.toString());
      }
      return;
    }
    try {
      await camera.startVideoRecording();
      _started = DateTime.now();
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted) setState(() {});
        final started = _started;
        if (started != null &&
            DateTime.now().difference(started).inSeconds >= 60) {
          _toggleRecord();
        }
      });
      setState(() => _recording = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _camera?.dispose();
    super.dispose();
  }

  String _elapsed() {
    final started = _started;
    if (started == null) return '0:00';
    final sec = DateTime.now().difference(started).inSeconds.clamp(0, 60);
    return '0:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final camera = _camera;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(strings.circleRecordTitle),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipOval(
                  child: camera != null && camera.value.isInitialized
                      ? FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: camera.value.previewSize?.height ?? 320,
                            height: camera.value.previewSize?.width ?? 320,
                            child: CameraPreview(camera),
                          ),
                        )
                      : ColoredBox(
                          color: MurkotColors.night,
                          child: Center(
                            child: _error == null
                                ? const CircularProgressIndicator()
                                : Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      strings.circleCameraFallback,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                  ),
                          ),
                        ),
                ),
              ),
            ),
          ),
          if (_recording)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${strings.recording} ${_elapsed()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: _fallbackPick,
                  child: Text(strings.circleUseSystemCamera),
                ),
                GestureDetector(
                  onTap: _toggleRecord,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: _recording ? Colors.redAccent : Colors.white24,
                    ),
                    child: Icon(
                      _recording ? Icons.stop : Icons.fiber_manual_record,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(width: 72),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
