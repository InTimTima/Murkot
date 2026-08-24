import 'package:flutter/material.dart';

import '../config/brand_theme.dart';
import '../l10n/app_strings.dart';
import '../services/settings_service.dart';
import 'murkot_decor.dart';

/// Returns true when the user may continue (signed in).
/// Guests see a register sheet; tapping register leaves guest mode.
Future<bool> ensureRegistered(
  BuildContext context, {
  required SettingsService settings,
}) async {
  if (!settings.isGuest) return true;
  final go = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final strings = context.strings;
      final theme = Theme.of(context);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MurkotLogoMark(size: 92),
              const SizedBox(height: 12),
              Text(
                strings.guestGateTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                strings.guestGateBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: MurkotColors.orange,
                ),
                child: Text(strings.guestRegister),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(strings.guestKeepBrowsing),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (go == true) {
    await settings.setGuest(false);
  }
  return false;
}
