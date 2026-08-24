import 'dart:math' as math;

import 'package:flutter/material.dart';

enum WallpaperFx { none, waves, wind, aurora, sparks, mist }

class WallpaperFxLayer extends StatefulWidget {
  const WallpaperFxLayer({super.key, required this.fx});

  final WallpaperFx fx;

  @override
  State<WallpaperFxLayer> createState() => _WallpaperFxLayerState();
}

class _WallpaperFxLayerState extends State<WallpaperFxLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tick;

  @override
  void initState() {
    super.initState();
    _tick = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    if (widget.fx != WallpaperFx.none) {
      _tick.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant WallpaperFxLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fx == WallpaperFx.none) {
      _tick.stop();
    } else if (!_tick.isAnimating) {
      _tick.repeat();
    }
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fx == WallpaperFx.none) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _tick,
      builder: (context, _) {
        return CustomPaint(
          painter: _FxPainter(fx: widget.fx, t: _tick.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _FxPainter extends CustomPainter {
  _FxPainter({required this.fx, required this.t});

  final WallpaperFx fx;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    switch (fx) {
      case WallpaperFx.none:
        return;
      case WallpaperFx.waves:
        _waves(canvas, size);
      case WallpaperFx.wind:
        _wind(canvas, size);
      case WallpaperFx.aurora:
        _aurora(canvas, size);
      case WallpaperFx.sparks:
        _sparks(canvas, size);
      case WallpaperFx.mist:
        _mist(canvas, size);
    }
  }

  void _waves(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.22);
    for (var i = 0; i < 5; i++) {
      final path = Path();
      final yBase = size.height * (0.35 + i * 0.12);
      path.moveTo(0, yBase);
      for (var x = 0.0; x <= size.width; x += 8) {
        final y = yBase +
            math.sin((x / size.width) * math.pi * 2 + t * math.pi * 2 + i) *
                (8 + i * 3);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _wind(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: 0.18);
    for (var i = 0; i < 10; i++) {
      final y = size.height * (0.1 + i * 0.08);
      final path = Path();
      final shift = (t + i * 0.07) % 1;
      path.moveTo(-40 + shift * size.width, y);
      path.cubicTo(
        size.width * 0.3 + shift * 20,
        y - 12,
        size.width * 0.6,
        y + 14,
        size.width + 20,
        y,
      );
      canvas.drawPath(path, paint);
    }
  }

  void _aurora(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            [
              const Color(0x8840F2A0),
              const Color(0x6650C4FF),
              const Color(0x77C56CFF),
            ][i],
            Colors.transparent,
          ],
        ).createShader(Offset.zero & size);
      final path = Path();
      final mid = size.width * (0.25 + i * 0.25) +
          math.sin(t * math.pi * 2 + i) * 30;
      path.moveTo(mid - 80, 0);
      path.quadraticBezierTo(mid, size.height * 0.55, mid + 40, size.height);
      path.quadraticBezierTo(mid + 90, size.height * 0.4, mid + 70, 0);
      canvas.drawPath(path, paint);
    }
  }

  void _sparks(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.7);
    for (var i = 0; i < 28; i++) {
      final x = rnd.nextDouble() * size.width;
      final base = rnd.nextDouble();
      final y = ((base + t) % 1) * size.height;
      canvas.drawCircle(Offset(x, y), 1.3 + rnd.nextDouble() * 1.4, paint);
    }
  }

  void _mist(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    for (var i = 0; i < 4; i++) {
      final cx = size.width * ((i * 0.3 + t * 0.2) % 1);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, size.height * (0.3 + i * 0.15)),
          width: size.width * 0.7,
          height: 70,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FxPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.fx != fx;
}
