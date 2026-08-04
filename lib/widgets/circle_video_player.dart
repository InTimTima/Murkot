import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class CircleVideoPlayer extends StatefulWidget {
  const CircleVideoPlayer({
    super.key,
    required this.url,
    this.size = 180,
  });

  final String url;
  final double size;

  @override
  State<CircleVideoPlayer> createState() => _CircleVideoPlayerState();
}

class _CircleVideoPlayerState extends State<CircleVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _failed = true);
      });
    _controller.setLooping(true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (!_ready) return;
    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      await _controller.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Center(child: Icon(Icons.broken_image_outlined)),
      );
    }

    return GestureDetector(
      onTap: _toggle,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: ClipOval(
          child: ColoredBox(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_ready)
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  )
                else
                  const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                if (_ready && !_controller.value.isPlaying)
                  const Center(
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white70,
                      size: 48,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
