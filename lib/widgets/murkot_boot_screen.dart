import 'package:flutter/material.dart';

import '../config/brand_theme.dart';
import '../l10n/app_strings.dart';
import 'murkot_decor.dart';
import 'unlumen/murkot_fx.dart';

/// Single boot visual used everywhere: murkot4 cat + juice loader
/// on the same orange gradient as `web/index.html`.
class MurkotBootScreen extends StatelessWidget {
  const MurkotBootScreen({
    super.key,
    this.title,
    this.subtitle,
    this.onRetry,
    this.onContinue,
    this.continueLabel,
  });

  final String? title;
  final String? subtitle;
  final VoidCallback? onRetry;
  final VoidCallback? onContinue;
  final String? continueLabel;

  @override
  Widget build(BuildContext context) {
    final strings = AppStringsScope.maybeOf(context);
    final label = title ?? strings?.loadingMurkot ?? 'Loading Murkot…';

    return Material(
      color: const Color(0xFFFFFBF0),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: MurkotColors.bootGradient,
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const StretchCatSilhouette(width: 200),
                  const SizedBox(height: 24),
                  const MurkotLoader(size: 52),
                  const SizedBox(height: 16),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFE07010),
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFE07010),
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (onContinue != null || onRetry != null) ...[
                    const SizedBox(height: 24),
                    if (onContinue != null)
                      FilledButton(
                        onPressed: onContinue,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(220, 48),
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF3A1C08),
                        ),
                        child: Text(
                          continueLabel ??
                              strings?.continueAnyway ??
                              'Continue',
                        ),
                      ),
                    if (onRetry != null) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: onRetry,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF3A1C08),
                        ),
                        child: Text(strings?.retry ?? 'Retry'),
                      ),
                    ],
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
