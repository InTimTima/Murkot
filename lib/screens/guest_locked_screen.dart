import 'package:flutter/material.dart';

import '../config/brand_theme.dart';
import '../l10n/app_strings.dart';
import '../services/settings_service.dart';
import '../widgets/murkot_decor.dart';

class GuestLockedScreen extends StatelessWidget {
  const GuestLockedScreen({
    super.key,
    required this.settingsService,
    required this.title,
    required this.body,
  });

  final SettingsService settingsService;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = context.strings;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const MurkotLogoMark(size: 160),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.45,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => settingsService.setGuest(false),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(220, 48),
                  backgroundColor: MurkotColors.orange,
                ),
                child: Text(strings.guestRegister),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
