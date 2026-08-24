import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../l10n/app_strings.dart';

/// Pan/zoom square crop. Captures the viewport via [RepaintBoundary].
Future<Uint8List?> showImageCropDialog(
  BuildContext context, {
  required Uint8List bytes,
}) {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ImageCropDialog(bytes: bytes),
  );
}

class _ImageCropDialog extends StatefulWidget {
  const _ImageCropDialog({required this.bytes});

  final Uint8List bytes;

  @override
  State<_ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<_ImageCropDialog> {
  final _boundaryKey = GlobalKey();
  final _transform = TransformationController();
  bool _busy = false;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    await Future<void>.delayed(Duration.zero);
    final boundary = _boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      setState(() => _busy = false);
      return;
    }
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (!mounted) return;
    if (data == null) {
      setState(() => _busy = false);
      return;
    }
    Navigator.pop(context, data.buffer.asUint8List());
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return AlertDialog(
      title: Text(strings.cropAvatarTitle),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.cropAvatarHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ClipOval(
              child: SizedBox(
                width: 260,
                height: 260,
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: InteractiveViewer(
                    transformationController: _transform,
                    minScale: 1,
                    maxScale: 4,
                    constrained: false,
                    child: Image.memory(
                      widget.bytes,
                      width: 260,
                      height: 260,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _confirm,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(strings.save),
        ),
      ],
    );
  }
}
