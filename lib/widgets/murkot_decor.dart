import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/brand_theme.dart';

/// Stylized citrus half-slice (Murkot juice motif).
class CitrusSlice extends StatelessWidget {
  const CitrusSlice({
    super.key,
    this.size = 48,
    this.color = MurkotColors.orange,
    this.opacity = 0.9,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: CustomPaint(
        size: Size.square(size),
        painter: _CitrusSlicePainter(color),
      ),
    );
  }
}

class _CitrusSlicePainter extends CustomPainter {
  _CitrusSlicePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.55);
    final radius = size.width * 0.42;
    final rind = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08;
    final fill = Paint()..color = color.withValues(alpha: 0.22);
    final segment = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = size.width * 0.035
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, fill);
    canvas.drawCircle(center, radius, rind);

    const segments = 6;
    for (var i = 0; i < segments; i++) {
      final a = -math.pi / 2 + (i * 2 * math.pi / segments);
      canvas.drawLine(
        center,
        center + Offset(math.cos(a), math.sin(a)) * radius * 0.88,
        segment,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CitrusSlicePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Stretching-cat silhouette (brand row 3).
class StretchCatSilhouette extends StatelessWidget {
  const StretchCatSilhouette({
    super.key,
    this.width = 120,
    this.color = MurkotColors.orange,
    this.opacity = 0.18,
  });

  final double width;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: CustomPaint(
        size: Size(width, width * 0.55),
        painter: _StretchCatPainter(color),
      ),
    );
  }
}

class _StretchCatPainter extends CustomPainter {
  _StretchCatPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    // Simplified play-bow silhouette.
    final w = size.width;
    final h = size.height;

    // Head
    path.addOval(Rect.fromCenter(
      center: Offset(w * 0.12, h * 0.55),
      width: w * 0.18,
      height: h * 0.32,
    ));
    // Ears
    path.moveTo(w * 0.05, h * 0.42);
    path.lineTo(w * 0.08, h * 0.22);
    path.lineTo(w * 0.14, h * 0.42);
    path.close();
    path.moveTo(w * 0.14, h * 0.4);
    path.lineTo(w * 0.18, h * 0.2);
    path.lineTo(w * 0.22, h * 0.42);
    path.close();

    // Body bow
    path.moveTo(w * 0.18, h * 0.62);
    path.quadraticBezierTo(w * 0.4, h * 0.85, w * 0.55, h * 0.55);
    path.quadraticBezierTo(w * 0.68, h * 0.2, w * 0.78, h * 0.38);
    path.quadraticBezierTo(w * 0.72, h * 0.7, w * 0.5, h * 0.78);
    path.quadraticBezierTo(w * 0.3, h * 0.85, w * 0.18, h * 0.68);
    path.close();

    // Tail arc
    final tail = Path()
      ..moveTo(w * 0.78, h * 0.4)
      ..quadraticBezierTo(w * 0.95, h * 0.05, w * 0.88, h * 0.55)
      ..quadraticBezierTo(w * 0.9, h * 0.35, w * 0.8, h * 0.42);
    path.addPath(tail, Offset.zero);

    // Front paws
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.2, h * 0.72, w * 0.22, h * 0.1),
      const Radius.circular(8),
    ));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StretchCatPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Soft juice droplet accent.
class JuiceDrop extends StatelessWidget {
  const JuiceDrop({
    super.key,
    this.size = 14,
    this.color = MurkotColors.orange,
    this.opacity = 0.55,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: CustomPaint(
        size: Size(size, size * 1.35),
        painter: _DropPainter(color),
      ),
    );
  }
}

class _DropPainter extends CustomPainter {
  _DropPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..quadraticBezierTo(size.width, size.height * 0.45, size.width / 2, size.height)
      ..quadraticBezierTo(0, size.height * 0.45, size.width / 2, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DropPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Decorative background wash for auth / empty states.
class MurkotAtmosphere extends StatelessWidget {
  const MurkotAtmosphere({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: MurkotColors.softGradient),
          ),
        ),
        Positioned(
          top: -20,
          right: -10,
          child: CitrusSlice(size: 120, opacity: 0.35),
        ),
        Positioned(
          top: 80,
          left: -30,
          child: CitrusSlice(
            size: 90,
            color: MurkotColors.yellow,
            opacity: 0.4,
          ),
        ),
        const Positioned(
          bottom: 40,
          right: 24,
          child: StretchCatSilhouette(width: 140),
        ),
        Positioned(
          bottom: 120,
          left: 36,
          child: JuiceDrop(size: 18, opacity: 0.4),
        ),
        Positioned(
          bottom: 160,
          left: 58,
          child: JuiceDrop(size: 12, color: MurkotColors.yellow, opacity: 0.5),
        ),
        if (child != null) Positioned.fill(child: child!),
      ],
    );
  }
}
