import 'package:flutter/material.dart';
import 'dart:math' as math;

class MurkotVibrantBg extends StatelessWidget {
  const MurkotVibrantBg({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        // Base gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF1A1207), const Color(0xFF2D1B0E), const Color(0xFF4A2C1A)]
                  : [const Color(0xFFFFF6E8), const Color(0xFFFFE8C8), const Color(0xFFFFD4A3)],
            ),
          ),
        ),
        // Geometric shapes
        Positioned.fill(
          child: CustomPaint(painter: _VibrantPainter(isDark: isDark)),
        ),
        child,
      ],
    );
  }
}

class _VibrantPainter extends CustomPainter {
  _VibrantPainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(42);
    final colors = isDark
        ? [const Color(0xFFFF8C42).withValues(alpha: 0.08), const Color(0xFFFFD23F).withValues(alpha: 0.06), const Color(0xFF6BCB77).withValues(alpha: 0.05)]
        : [const Color(0xFFFF8C42).withValues(alpha: 0.12), const Color(0xFFFF6B35).withValues(alpha: 0.08), const Color(0xFF4ECDC4).withValues(alpha: 0.07)];

    // Circles
    for (int i = 0; i < 6; i++) {
      final c = colors[i % colors.length];
      final r = 40 + rnd.nextDouble() * 80;
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), r, Paint()..color = c);
    }

    // Waves
    for (int i = 0; i < 3; i++) {
      final path = Path();
      final yBase = size.height * (0.3 + i * 0.2);
      path.moveTo(0, yBase);
      for (double x = 0; x < size.width; x += 20) {
        final y = yBase + math.sin((x / size.width * math.pi * 2) + i) * 18 + rnd.nextDouble() * 6;
        path.lineTo(x, y);
      }
      path.lineTo(size.width, yBase + 40);
      path.lineTo(0, yBase + 40);
      path.close();
      canvas.drawPath(path, Paint()..color = colors[i % colors.length].withValues(alpha: 0.04)..style = PaintingStyle.fill);
    }

    // Geometric triangles
    for (int i = 0; i < 4; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final s = 18 + rnd.nextDouble() * 24;
      final path = Path()
        ..moveTo(x, y)
        ..lineTo(x + s, y + s * 0.6)
        ..lineTo(x - s * 0.3, y + s)
        ..close();
      canvas.drawPath(path, Paint()..color = colors[i % colors.length].withValues(alpha: 0.05));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
