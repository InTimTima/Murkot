import 'package:flutter/material.dart';

import '../config/brand_theme.dart';
import '../l10n/app_strings.dart';
import 'murkot_decor.dart';

/// Atmospheric "restoring session" screen shown while the shell hydrates.
class SessionBootOverlay extends StatefulWidget {
  const SessionBootOverlay({
    super.key,
    this.failed = false,
    this.onOpenWorkspace,
    this.onRetry,
  });

  final bool failed;
  final VoidCallback? onOpenWorkspace;
  final VoidCallback? onRetry;

  @override
  State<SessionBootOverlay> createState() => _SessionBootOverlayState();
}

class _SessionBootOverlayState extends State<SessionBootOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final failed = widget.failed;

    return Material(
      color: theme.brightness == Brightness.light
          ? MurkotColors.cream
          : const Color(0xFF1A140C),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    final t = Curves.easeInOut.transform(_pulse.value);
                    return Transform.scale(
                      scale: 0.94 + (t * 0.08),
                      child: Opacity(
                        opacity: 0.75 + (t * 0.25),
                        child: child,
                      ),
                    );
                  },
                  child: const Stack(
                    alignment: Alignment.center,
                    children: [
                      CitrusSlice(size: 96, opacity: 0.7),
                      StretchCatSilhouette(width: 120, opacity: 0.4),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      MurkotColors.brandGradient.createShader(bounds),
                  child: Text(
                    strings.appTitle,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  failed
                      ? strings.sessionBootFailedTitle
                      : strings.sessionBootTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  failed
                      ? strings.sessionBootFailedSubtitle
                      : strings.sessionBootSubtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 28),
                if (!failed)
                  SizedBox(
                    width: 160,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        backgroundColor:
                            MurkotColors.orange.withValues(alpha: 0.15),
                        color: MurkotColors.orange,
                      ),
                    ),
                  )
                else ...[
                  FilledButton(
                    onPressed: widget.onOpenWorkspace,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(220, 48),
                    ),
                    child: Text(strings.openWorkspace),
                  ),
                  if (widget.onRetry != null) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: widget.onRetry,
                      child: Text(strings.retry),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
