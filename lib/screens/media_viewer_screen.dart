import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../widgets/unlumen/murkot_fx.dart';

/// Fullscreen in-app viewer for chat images with left/right swiping.
class MediaViewerScreen extends StatefulWidget {
  const MediaViewerScreen({
    super.key,
    required this.urls,
    this.initialIndex = 0,
    this.title,
  });

  final List<String> urls;
  final int initialIndex;
  final String? title;

  static void open(
    BuildContext context, {
    required List<String> urls,
    int initialIndex = 0,
    String? title,
  }) {
    if (urls.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MediaViewerScreen(
          urls: urls,
          initialIndex: initialIndex.clamp(0, urls.length - 1),
          title: title,
        ),
      ),
    );
  }

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.urls.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.6),
        foregroundColor: Colors.white,
        leading: const MurkotBackButton(),
        title: Text(
          widget.title ??
              (total > 1
                  ? context.strings.mediaOf(_index + 1, total)
                  : ''),
          style: const TextStyle(fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: total,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    widget.urls[index],
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                            ? child
                            : const Center(
                                child: MurkotLoader(
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 64,
                    ),
                  ),
                ),
              );
            },
          ),
          if (total > 1 && _index > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: _ArrowButton(
                icon: Icons.chevron_left,
                onTap: () => _controller.previousPage(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                ),
              ),
            ),
          if (total > 1 && _index < total - 1)
            Align(
              alignment: Alignment.centerRight,
              child: _ArrowButton(
                icon: Icons.chevron_right,
                onTap: () => _controller.nextPage(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.white.withValues(alpha: 0.15),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}
