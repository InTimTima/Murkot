import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/brand_theme.dart';
import '../../services/settings_service.dart';

/// Coordinates curtain animation around theme snaps.
///
/// ThemeData.lerp is too heavy on Flutter Web. We snap the theme while a
/// full-screen curtain covers the UI, then lift the curtain.
class MurkotThemeTransition {
  MurkotThemeTransition._();
  static final instance = MurkotThemeTransition._();

  Future<void> Function(
    Future<void> Function() apply, {
    required ThemeMode next,
    required bool nextIsDark,
  })? _handler;

  void bind(
    Future<void> Function(
      Future<void> Function() apply, {
      required ThemeMode next,
      required bool nextIsDark,
    }) handler,
  ) {
    _handler = handler;
  }

  void unbind() => _handler = null;

  Future<void> run(
    Future<void> Function() apply, {
    required ThemeMode next,
    required bool nextIsDark,
  }) async {
    final handler = _handler;
    if (handler == null) {
      await apply();
      return;
    }
    await handler(apply, next: next, nextIsDark: nextIsDark);
  }
}

/// Curtain overlay inside [MaterialApp.builder].
/// Drops from the top (faster in the middle via ease-in-out), theme snaps,
/// then rises back up.
class MurkotThemeCurtain extends StatefulWidget {
  const MurkotThemeCurtain({
    super.key,
    required this.settings,
    required this.child,
  });

  final SettingsService settings;
  final Widget child;

  @override
  State<MurkotThemeCurtain> createState() => _MurkotThemeCurtainState();
}

class _MurkotThemeCurtainState extends State<MurkotThemeCurtain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _curtain;
  bool _nextIsDark = false;
  bool _busy = false;

  /// Slow at the edges, faster through the middle.
  static const _curve = Curves.easeInOutCubic;

  @override
  void initState() {
    super.initState();
    _curtain = AnimationController.unbounded(vsync: this);
    MurkotThemeTransition.instance.bind(_handle);
  }

  @override
  void dispose() {
    MurkotThemeTransition.instance.unbind();
    _curtain.dispose();
    super.dispose();
  }

  Future<void> _animateTo(double target, {required int ms}) {
    return _curtain.animateTo(
      target,
      duration: Duration(milliseconds: ms),
      curve: _curve,
    );
  }

  Future<void> _handle(
    Future<void> Function() apply, {
    required ThemeMode next,
    required bool nextIsDark,
  }) async {
    if (!widget.settings.smoothTheme || _busy) {
      await apply();
      return;
    }
    _busy = true;
    _nextIsDark = nextIsDark;
    if (mounted) setState(() {});
    try {
      await _animateTo(1, ms: 480);
      await apply();
      await Future<void>.delayed(const Duration(milliseconds: 24));
      await _animateTo(0, ms: 520);
    } finally {
      _busy = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curtain,
      builder: (context, _) {
        final t = _curtain.value.clamp(0.0, 1.0);
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (t > 0.001)
              IgnorePointer(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: FractionallySizedBox(
                    widthFactor: 1,
                    heightFactor: t,
                    alignment: Alignment.topCenter,
                    child: _CurtainPanel(dark: _nextIsDark, progress: t),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CurtainPanel extends StatelessWidget {
  const _CurtainPanel({required this.dark, required this.progress});

  final bool dark;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = dark
        ? const [
            Color(0xFF1E160F),
            Color(0xFF2E2016),
            Color(0xFF5A3820),
            MurkotColors.deepOrange,
          ]
        : const [
            MurkotColors.cream,
            MurkotColors.pulp,
            MurkotColors.yellow,
            MurkotColors.orange,
          ];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          // Even distribution — same spacing as the light curtain.
          stops: const [0.0, 0.33, 0.66, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22 * progress),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const SizedBox.expand(),
    );
  }
}
