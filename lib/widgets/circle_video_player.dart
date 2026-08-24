import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'unlumen/murkot_fx.dart';

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
  bool _showControls = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _ready = true;
          _duration = _controller.value.duration;
        });
        _controller.play();
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _failed = true);
      });
    _controller.setLooping(false);
    _controller.addListener(_onTick);
  }

  void _onTick() {
    if (!_ready || !mounted) return;
    final pos = _controller.value.position;
    final dur = _controller.value.duration;
    if (pos != _position || dur != _duration) {
      setState(() {
        _position = pos;
        _duration = dur;
      });
    }
    // Auto-show play icon when finished
    if (!_controller.value.isPlaying && _controller.value.position >= _controller.value.duration) {
      setState(() => _showControls = true);
    }
  }

  @override
  void didUpdateWidget(covariant CircleVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller.removeListener(_onTick);
      _controller.dispose();
      _ready = false;
      _failed = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {
            _ready = true;
            _duration = _controller.value.duration;
          });
          _controller.play();
        }).catchError((_) {
          if (!mounted) return;
          setState(() => _failed = true);
        });
      _controller.setLooping(false);
      _controller.addListener(_onTick);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (!_ready) return;
    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      // Replay from start if finished
      if (_position >= _duration && _duration != Duration.zero) {
        await _controller.seekTo(Duration.zero);
      }
      await _controller.play();
    }
    setState(() => _showControls = !_controller.value.isPlaying);
  }

  Future<void> _seek(double fraction) async {
    if (!_ready || _duration == Duration.zero) return;
    final target = Duration(milliseconds: (_duration.inMilliseconds * fraction).round());
    await _controller.seekTo(target);
  }

  void _openFullscreen() {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio == 0 ? 1 : _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: _buildControls(fullscreen: true),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildControls({bool fullscreen = false}) {
    final progress = _duration.inMilliseconds == 0 ? 0.0 : _position.inMilliseconds / _duration.inMilliseconds;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Slider(
          value: progress.clamp(0.0, 1.0),
          onChanged: _seek,
          activeColor: Colors.white,
          inactiveColor: Colors.white24,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${_fmt(_position)} / ${_fmt(_duration)}', style: TextStyle(color: Colors.white70, fontSize: fullscreen ? 12 : 10)),
            Row(
              children: [
                IconButton(
                  icon: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: fullscreen ? 28 : 20),
                  onPressed: _toggle,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints.tightFor(width: fullscreen ? 36 : 28, height: fullscreen ? 36 : 28),
                ),
                if (fullscreen)
                  IconButton(
                    icon: Icon(_controller.value.volume == 0 ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 22),
                    onPressed: () => _controller.setVolume(_controller.value.volume == 0 ? 1 : 0),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
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
      onTap: () => setState(() => _showControls = !_showControls),
      onDoubleTap: _toggle,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          children: [
            ClipOval(
              child: ColoredBox(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_ready)
                      InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 4.0,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _controller.value.size.width,
                            height: _controller.value.size.height,
                            child: VideoPlayer(_controller),
                          ),
                        ),
                      )
                    else
                      const Center(child: MurkotLoader(size: 28)),
                    if (_ready && !_controller.value.isPlaying && _showControls)
                      const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 48)),
                  ],
                ),
              ),
            ),
            // Expand button top-right
            if (_ready)
              Positioned(
                top: 6,
                right: 6,
                child: InkWell(
                  onTap: _openFullscreen,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.open_in_full, color: Colors.white70, size: 14),
                  ),
                ),
              ),
            // Bottom scrub bar when controls shown
            if (_ready && _showControls)
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                  child: _buildControls(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
