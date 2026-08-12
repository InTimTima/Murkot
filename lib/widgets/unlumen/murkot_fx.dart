import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../config/brand_theme.dart';
import '../../l10n/app_strings.dart';
import '../../services/settings_service.dart';

// ───────────────────────────────────────────── Theme switch
/// Cycles ThemeMode: system → light → dark → system.
class MurkotThemeSwitch extends StatefulWidget {
  const MurkotThemeSwitch({
    super.key,
    required this.settings,
    this.size = 36,
    this.iconSize = 16,
  });

  final SettingsService settings;
  final double size;
  final double iconSize;

  @override
  State<MurkotThemeSwitch> createState() => _MurkotThemeSwitchState();
}

class _MurkotThemeSwitchState extends State<MurkotThemeSwitch> {
  void _cycle() {
    final mode = widget.settings.themeMode;
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    // system → (light if OS dark, dark if OS light) → the other forced → system
    // Simplified readable cycle: system → light → dark → system,
    // but first step from system prefers opposite of current OS.
    final ThemeMode next;
    switch (mode) {
      case ThemeMode.system:
        next = platformDark ? ThemeMode.light : ThemeMode.dark;
      case ThemeMode.light:
        next = ThemeMode.dark;
      case ThemeMode.dark:
        next = ThemeMode.system;
    }
    widget.settings.setThemeMode(next);
  }

  IconData _icon(ThemeMode mode, bool platformDark) {
    return switch (mode) {
      ThemeMode.system => Icons.brightness_auto_rounded,
      ThemeMode.light => Icons.wb_sunny_rounded,
      ThemeMode.dark => Icons.nightlight_round,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        final mode = widget.settings.themeMode;
        final strings = AppStringsScope.maybeOf(context);
        final message = strings == null
            ? 'Theme'
            : switch (mode) {
                ThemeMode.system =>
                  '${strings.theme}: ${strings.themeSystem}',
                ThemeMode.light =>
                  '${strings.theme}: ${strings.themeLight}',
                ThemeMode.dark =>
                  '${strings.theme}: ${strings.themeDark}',
              };

        return MurkotFloatingTooltip(
          message: message,
          settings: widget.settings,
          child: Material(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.9),
            shape: const CircleBorder(),
            elevation: 1,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _cycle,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 640),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) {
                    final curved = CurvedAnimation(
                      parent: anim,
                      curve: Curves.easeInOutCubicEmphasized,
                    );
                    return FadeTransition(
                      opacity: curved,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.78, end: 1.0).animate(curved),
                        child: RotationTransition(
                          turns: Tween(begin: 0.08, end: 0.0).animate(curved),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Icon(
                    _icon(mode, platformDark),
                    key: ValueKey(mode),
                    size: widget.iconSize,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────────────────────────── Auth wavy spotlight
/// Appears when the pointer is outside [cardKey], follows cursor with a wavy rim.
class AuthWavySpotlight extends StatefulWidget {
  const AuthWavySpotlight({
    super.key,
    required this.cardKey,
    required this.child,
    this.enabled = true,
  });

  final GlobalKey cardKey;
  final Widget child;
  final bool enabled;

  @override
  State<AuthWavySpotlight> createState() => _AuthWavySpotlightState();
}

class _AuthWavySpotlightState extends State<AuthWavySpotlight>
    with TickerProviderStateMixin {
  late final AnimationController _wave;
  late final AnimationController _fade;
  Offset _localPos = Offset.zero;

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
  }

  @override
  void didUpdateWidget(covariant AuthWavySpotlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      _fade.reverse();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    _fade.dispose();
    super.dispose();
  }

  bool _pointerOverCard(Offset global) {
    final box =
        widget.cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return true;
    final topLeft = box.localToGlobal(Offset.zero);
    final rect = topLeft & box.size;
    return rect.contains(global);
  }

  void _onHover(PointerHoverEvent e) {
    final over = _pointerOverCard(e.position);
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    setState(() => _localPos = box.globalToLocal(e.position));
    if (over) {
      _fade.reverse();
    } else {
      _fade.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark
        ? MurkotColors.cream.withValues(alpha: 0.88)
        : const Color(0xFF2A1A0C).withValues(alpha: 0.88);

    return MouseRegion(
      onHover: _onHover,
      onExit: (_) => _fade.reverse(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _fade,
                  curve: Curves.easeInOutCubic,
                ),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_wave, _fade]),
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _WavySpotlightPainter(
                        center: _localPos,
                        radius: 160,
                        phase: _wave.value * math.pi * 2,
                        color: fill,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WavySpotlightPainter extends CustomPainter {
  _WavySpotlightPainter({
    required this.center,
    required this.radius,
    required this.phase,
    required this.color,
  });

  final Offset center;
  final double radius;
  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    const steps = 64;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps * math.pi * 2;
      final wave = math.sin(t * 5 + phase) * 10 + math.sin(t * 3 - phase) * 6;
      final r = radius + wave;
      final p = Offset(
        center.dx + math.cos(t) * r,
        center.dy + math.sin(t) * r,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..blendMode = BlendMode.difference,
    );
  }

  @override
  bool shouldRepaint(covariant _WavySpotlightPainter oldDelegate) =>
      oldDelegate.center != center ||
      oldDelegate.phase != phase ||
      oldDelegate.color != color;
}

// ───────────────────────────────────────────── Shimmer skeleton
class MurkotShimmer extends StatefulWidget {
  const MurkotShimmer({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
    this.isCircle = false,
  });

  final double? width;
  final double height;
  final double borderRadius;
  final bool isCircle;

  @override
  State<MurkotShimmer> createState() => _MurkotShimmerState();
}

class _MurkotShimmerState extends State<MurkotShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).brightness == Brightness.dark
        ? MurkotColors.nightElevated
        : MurkotColors.pulp.withValues(alpha: 0.55);

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Container(
          width: widget.isCircle ? widget.height : widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.isCircle
                ? null
                : BorderRadius.circular(widget.borderRadius),
            shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
            gradient: LinearGradient(
              begin: Alignment(-1.2 + _c.value * 2.4, 0),
              end: Alignment(-0.2 + _c.value * 2.4, 0),
              colors: [
                base,
                Color.lerp(base, Colors.white, 0.35)!,
                base,
              ],
            ),
          ),
        );
      },
    );
  }
}

class ConversationListSkeleton extends StatelessWidget {
  const ConversationListSkeleton({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            MurkotShimmer(height: 48, isCircle: true),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MurkotShimmer(width: 140, height: 14),
                  SizedBox(height: 8),
                  MurkotShimmer(width: 220, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Brand loading indicator — juice swirl: counter-rotating arcs,
/// pulsing core, and orbiting citrus wedges.
class MurkotLoader extends StatefulWidget {
  const MurkotLoader({
    super.key,
    this.size = 48,
    this.strokeWidth,
    this.color,
  });

  final double size;
  final double? strokeWidth;
  final Color? color;

  @override
  State<MurkotLoader> createState() => _MurkotLoaderState();
}

class _MurkotLoaderState extends State<MurkotLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final stroke = widget.strokeWidth ?? (widget.size * 0.085).clamp(2.0, 4.2);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return CustomPaint(
            painter: _MurkotLoaderPainter(
              progress: _c.value,
              color: color,
              strokeWidth: stroke,
            ),
          );
        },
      ),
    );
  }
}

class _MurkotLoaderPainter extends CustomPainter {
  _MurkotLoaderPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide / 2;
    final t = progress * math.pi * 2;

    // Soft expanding juice ripples.
    for (var i = 0; i < 3; i++) {
      final wave = (progress + i / 3) % 1.0;
      final r = maxR * (0.25 + wave * 0.75);
      final alpha = (1 - wave) * 0.22;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = MurkotColors.orange.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 0.7,
      );
    }

    // Outer dashed track.
    final trackR = maxR - strokeWidth * 1.2;
    final trackRect = Rect.fromCircle(center: center, radius: trackR);
    for (var i = 0; i < 12; i++) {
      final a0 = t * 0.35 + i * (math.pi * 2 / 12);
      canvas.drawArc(
        trackRect,
        a0,
        0.18,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth * 0.55,
      );
    }

    // Counter-rotating juice arcs.
    final arcR = trackR * 0.82;
    final arcRect = Rect.fromCircle(center: center, radius: arcR);
    canvas.drawArc(
      arcRect,
      t,
      1.9,
      false,
      Paint()
        ..color = MurkotColors.yellow
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth * 1.15,
    );
    canvas.drawArc(
      arcRect,
      -t * 1.25 + math.pi,
      1.35,
      false,
      Paint()
        ..color = MurkotColors.deepOrange
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth,
    );

    // Orbiting citrus wedges (teardrop-ish dots with trail).
    for (var i = 0; i < 4; i++) {
      final a = t * 1.1 + i * (math.pi / 2);
      final orbit = arcR * 0.55;
      final pulse = 0.75 + 0.25 * math.sin(t * 2 + i);
      final p = Offset(
        center.dx + math.cos(a) * orbit,
        center.dy + math.sin(a) * orbit,
      );
      final c = [
        MurkotColors.yellow,
        MurkotColors.orange,
        MurkotColors.deepOrange,
        MurkotColors.pulp,
      ][i];
      canvas.drawCircle(
        p,
        strokeWidth * 1.35 * pulse,
        Paint()..color = c,
      );
      // Tiny highlight.
      canvas.drawCircle(
        p.translate(-strokeWidth * 0.35, -strokeWidth * 0.35),
        strokeWidth * 0.35 * pulse,
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
    }

    // Pulsing core.
    final core = strokeWidth * (1.6 + 0.45 * math.sin(t * 2));
    canvas.drawCircle(
      center,
      core * 1.6,
      Paint()..color = MurkotColors.orange.withValues(alpha: 0.18),
    );
    canvas.drawCircle(
      center,
      core,
      Paint()
        ..shader = RadialGradient(
          colors: [
            MurkotColors.yellow,
            MurkotColors.orange,
            MurkotColors.deepOrange,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: core)),
    );
  }

  @override
  bool shouldRepaint(covariant _MurkotLoaderPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Compact loader for buttons / tight UI.
class MurkotLoaderCompact extends StatelessWidget {
  const MurkotLoaderCompact({
    super.key,
    this.size = 20,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return MurkotLoader(size: size, color: color, strokeWidth: 2.2);
  }
}

// ───────────────────────────────────────────── Shimmering text
class MurkotShimmerText extends StatefulWidget {
  const MurkotShimmerText(
    this.text, {
    super.key,
    this.style,
  });

  final String text;
  final TextStyle? style;

  @override
  State<MurkotShimmerText> createState() => _MurkotShimmerTextState();
}

class _MurkotShimmerTextState extends State<MurkotShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = widget.style ?? Theme.of(context).textTheme.bodyMedium;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1 + _c.value * 2, 0),
              end: Alignment(0 + _c.value * 2, 0),
              colors: const [
                MurkotColors.orange,
                MurkotColors.yellow,
                MurkotColors.cream,
                MurkotColors.orange,
              ],
            ).createShader(bounds);
          },
          child: Text(widget.text, style: baseStyle),
        );
      },
    );
  }
}

// ───────────────────────────────────────────── Switch / Slider
class MurkotSwitch extends StatelessWidget {
  const MurkotSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 52,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: value
              ? MurkotColors.brandGradient
              : null,
          color: value ? null : Colors.grey.shade400,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MurkotSlider extends StatelessWidget {
  const MurkotSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: MurkotColors.orange,
        inactiveTrackColor: MurkotColors.pulp,
        thumbColor: MurkotColors.yellow,
        overlayColor: MurkotColors.orange.withValues(alpha: 0.18),
        trackHeight: 5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }
}

// ───────────────────────────────────────────── Floating tooltip
class MurkotFloatingTooltip extends StatefulWidget {
  const MurkotFloatingTooltip({
    super.key,
    required this.message,
    required this.child,
    this.description,
    this.settings,
  });

  final String message;
  final String? description;
  final Widget child;
  final SettingsService? settings;

  @override
  State<MurkotFloatingTooltip> createState() => _MurkotFloatingTooltipState();
}

class _MurkotFloatingTooltipState extends State<MurkotFloatingTooltip>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _entry;
  Offset _pos = Offset.zero;
  late final AnimationController _fade;

  bool get _floatingEnabled {
    final settings = widget.settings ??
        AppStringsScope.maybeOf(context)?.settingsService;
    return settings?.floatingTooltips ?? true;
  }

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 120),
    );
  }

  void _show(Offset global) {
    if (!_floatingEnabled) return;
    _hide(immediate: true);
    _pos = global;
    _entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: _pos.dx + 14,
          top: _pos.dy + 14,
          child: IgnorePointer(
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _fade,
                curve: Curves.easeOutCubic,
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 220),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: MurkotColors.brandGradient,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      if (widget.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.description!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_entry!);
    _fade.forward(from: 0);
  }

  void _move(Offset global) {
    if (_entry == null) return;
    _pos = global;
    _entry?.markNeedsBuild();
  }

  Future<void> _hide({bool immediate = false}) async {
    final entry = _entry;
    if (entry == null) return;
    if (!immediate) {
      await _fade.reverse();
    } else {
      _fade.value = 0;
    }
    entry.remove();
    if (identical(_entry, entry)) _entry = null;
  }

  @override
  void dispose() {
    _fade.dispose();
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_floatingEnabled) {
      return Tooltip(
        message: widget.message,
        child: widget.child,
      );
    }

    return MouseRegion(
      onEnter: (e) => _show(e.position),
      onHover: (e) => _move(e.position),
      onExit: (_) => _hide(),
      child: widget.child,
    );
  }
}

/// AppBar back with a floating tooltip.
class MurkotBackButton extends StatelessWidget {
  const MurkotBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final strings = AppStringsScope.maybeOf(context);
    return MurkotFloatingTooltip(
      message: strings?.back ?? 'Back',
      child: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: '', // suppress default native tooltip when floating
        onPressed: onPressed ?? () => Navigator.maybePop(context),
      ),
    );
  }
}

// ───────────────────────────────────────────── Text reveal
class MurkotTextReveal extends StatefulWidget {
  const MurkotTextReveal({
    super.key,
    required this.text,
    this.style,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 900),
  });

  final String text;
  final TextStyle? style;
  final Duration delay;
  final Duration duration;

  @override
  State<MurkotTextReveal> createState() => _MurkotTextRevealState();
}

class _MurkotTextRevealState extends State<MurkotTextReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    Future<void>.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return ClipRect(
          child: Align(
            alignment: Alignment.topLeft,
            heightFactor: Curves.easeOutCubic.transform(_c.value).clamp(0.01, 1),
            child: Opacity(
              opacity: _c.value,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - _c.value)),
                child: Text(widget.text, style: widget.style),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────────────────────────── Velocity highlight
class MurkotVelocityHighlight extends StatefulWidget {
  const MurkotVelocityHighlight({
    super.key,
    required this.child,
    this.highlightColor,
  });

  final Widget child;
  final Color? highlightColor;

  @override
  State<MurkotVelocityHighlight> createState() =>
      _MurkotVelocityHighlightState();
}

class _MurkotVelocityHighlightState extends State<MurkotVelocityHighlight> {
  double _intensity = 0;
  Offset _last = Offset.zero;
  DateTime _lastTime = DateTime.now();

  void _onHover(PointerHoverEvent e) {
    final now = DateTime.now();
    final dt = now.difference(_lastTime).inMilliseconds.clamp(1, 100);
    final dist = (e.localPosition - _last).distance;
    final speed = dist / dt;
    _last = e.localPosition;
    _lastTime = now;
    setState(() => _intensity = (speed * 8).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final color = (widget.highlightColor ?? MurkotColors.yellow)
        .withValues(alpha: 0.18 * _intensity);
    return MouseRegion(
      onHover: _onHover,
      onExit: (_) => setState(() => _intensity = 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: widget.child,
      ),
    );
  }
}

// ───────────────────────────────────────────── Orbiting message actions
class OrbitAction {
  const OrbitAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
}

/// Orbital action ring that expands from [pressGlobal], stays pinned to
/// [anchorKey]'s local press point while scrolling, and shrinks away when
/// the message leaves the viewport.
class MurkotOrbitActions extends StatefulWidget {
  const MurkotOrbitActions({
    super.key,
    required this.actions,
    required this.pressGlobal,
    required this.anchorKey,
    required this.onDismiss,
    this.radius = 96,
  });

  final List<OrbitAction> actions;
  final Offset pressGlobal;
  final GlobalKey anchorKey;
  final VoidCallback onDismiss;
  final double radius;

  @override
  State<MurkotOrbitActions> createState() => _MurkotOrbitActionsState();
}

class _MurkotOrbitActionsState extends State<MurkotOrbitActions>
    with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _appear;
  late final AnimationController _exit;

  /// Press point relative to the message's top-left (stable across scroll).
  Offset _localInMessage = Offset.zero;
  Offset _center = Offset.zero;
  double _onScreen = 1;
  bool _tracking = true;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
    _appear = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1,
    );

    _captureLocalOffset();
    _center = widget.pressGlobal;
    _appear.forward();
    WidgetsBinding.instance.addPostFrameCallback(_tick);
  }

  void _captureLocalOffset() {
    final box =
        widget.anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && box.attached) {
      final origin = box.localToGlobal(Offset.zero);
      _localInMessage = widget.pressGlobal - origin;
    } else {
      _localInMessage = Offset.zero;
    }
  }

  void _tick(Duration _) {
    if (!mounted || !_tracking) return;

    final box =
        widget.anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) {
      _beginExit();
      return;
    }

    final origin = box.localToGlobal(Offset.zero);
    final rect = origin & box.size;
    final size = MediaQuery.sizeOf(context);
    final view = Offset.zero & size;

    final overlap = rect.intersect(view);
    final onScreen = rect.height <= 0
        ? 0.0
        : (overlap.height / rect.height).clamp(0.0, 1.0);

    final nextCenter = origin + _localInMessage;

    if (onScreen <= 0.02) {
      _beginExit();
      return;
    }

    setState(() {
      _center = nextCenter;
      _onScreen = onScreen;
    });

    WidgetsBinding.instance.addPostFrameCallback(_tick);
  }

  Future<void> _beginExit() async {
    if (_exiting) return;
    _exiting = true;
    _tracking = false;
    await _exit.animateTo(0, curve: Curves.easeInCubic);
    if (mounted) widget.onDismiss();
  }

  void _dismiss() {
    _beginExit();
  }

  @override
  void dispose() {
    _tracking = false;
    _spin.dispose();
    _appear.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.actions.length;
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismiss,
        child: AnimatedBuilder(
          animation: Listenable.merge([_spin, _appear, _exit]),
          builder: (context, _) {
            final expand = Curves.easeOutBack.transform(_appear.value);
            // Shrink as the message leaves the viewport / on dismiss.
            final life = (_exit.value * (0.25 + 0.75 * _onScreen)).clamp(0.0, 1.0);
            final scale = (expand * life).clamp(0.0, 1.2);
            final radius = widget.radius * scale;
            final fade = life;

            return Opacity(
              opacity: fade,
              child: Stack(
                children: [
                  CustomPaint(
                    size: Size.infinite,
                    painter: _OrbitRingPainter(
                      center: _center,
                      radius: radius,
                      color: MurkotColors.orange.withValues(
                        alpha: 0.28 * fade,
                      ),
                    ),
                  ),
                  for (var i = 0; i < n; i++)
                    _orbitBadge(i, n, widget.actions[i], radius, scale),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _orbitBadge(
    int i,
    int n,
    OrbitAction action,
    double radius,
    double scale,
  ) {
    final base = (i / n) * math.pi * 2;
    final angle = base + _spin.value * math.pi * 2;
    final dx = math.cos(angle) * radius;
    final dy = math.sin(angle) * radius;
    final theme = Theme.of(context);
    final badge = 56.0 * scale.clamp(0.35, 1.0);

    return Positioned(
      left: _center.dx + dx - badge / 2,
      top: _center.dy + dy - badge / 2,
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 4 * scale.clamp(0.0, 1.0),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            _tracking = false;
            widget.onDismiss();
            action.onTap();
          },
          child: SizedBox(
            width: badge,
            height: badge,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    action.icon,
                    size: 20 * scale.clamp(0.5, 1.0),
                    color: action.isDestructive
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                  if (scale > 0.55) ...[
                    const SizedBox(height: 2),
                    Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9 * scale.clamp(0.7, 1.0),
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbitRingPainter extends CustomPainter {
  _OrbitRingPainter({
    required this.center,
    required this.radius,
    required this.color,
  });

  final Offset center;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 1) return;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(
      center,
      4,
      Paint()..color = color.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitRingPainter oldDelegate) =>
      oldDelegate.center != center ||
      oldDelegate.radius != radius ||
      oldDelegate.color != color;
}
