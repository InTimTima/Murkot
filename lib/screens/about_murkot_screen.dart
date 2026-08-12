import 'package:flutter/material.dart';

import '../config/brand_theme.dart';
import '../l10n/app_strings.dart';
import '../services/settings_service.dart';
import '../widgets/murkot_decor.dart';
import '../widgets/unlumen/murkot_fx.dart';

/// About / project info — opened from the branded About nav slot.
class AboutMurkotScreen extends StatelessWidget {
  const AboutMurkotScreen({super.key, this.settingsService});

  final SettingsService? settingsService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = context.strings;
    final bodyStyle = theme.textTheme.bodyLarge?.copyWith(
      height: 1.5,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
    );

    return Scaffold(
      appBar: AppBar(
        leading: const MurkotBackButton(),
        title: Text(strings.aboutTitle),
        actions: [
          if (settingsService != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: MurkotThemeSwitch(settings: settingsService!),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
        children: [
          const Center(
            child: MurkotBrandImage(
              asset: MurkotAssets.appIconFull,
              width: 240,
            ),
          ),
          const SizedBox(height: 28),
          MurkotTextReveal(
            text: 'Murkot',
            delay: const Duration(milliseconds: 80),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          MurkotTextReveal(
            text: strings.aboutTagline,
            delay: const Duration(milliseconds: 220),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 28),
          MurkotTextReveal(
            text: strings.aboutBody1,
            delay: const Duration(milliseconds: 360),
            duration: const Duration(milliseconds: 1100),
            style: bodyStyle,
          ),
          const SizedBox(height: 16),
          MurkotTextReveal(
            text: strings.aboutBody2,
            delay: const Duration(milliseconds: 520),
            duration: const Duration(milliseconds: 1200),
            style: bodyStyle,
          ),
          const SizedBox(height: 16),
          MurkotTextReveal(
            text: strings.aboutBody3,
            delay: const Duration(milliseconds: 680),
            duration: const Duration(milliseconds: 1200),
            style: bodyStyle,
          ),
          const SizedBox(height: 28),
          MurkotTextReveal(
            text: strings.aboutTeam,
            delay: const Duration(milliseconds: 820),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _CreatorCard(
            name: 'Тима',
            role: strings.aboutCreator1Role,
            caption: strings.aboutPhotoSoon,
          ),
          const SizedBox(height: 20),
          _CreatorCard(
            name: strings.isRu ? 'Друг' : 'Friend',
            role: strings.aboutCreator2Role,
            caption: strings.aboutPhotoSoon,
          ),
          const SizedBox(height: 28),
          MurkotTextReveal(
            text: strings.aboutBody4,
            delay: const Duration(milliseconds: 980),
            duration: const Duration(milliseconds: 1300),
            style: bodyStyle,
          ),
          const SizedBox(height: 16),
          MurkotTextReveal(
            text: strings.aboutBody5,
            delay: const Duration(milliseconds: 1140),
            duration: const Duration(milliseconds: 1300),
            style: bodyStyle,
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '© Murkot',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatorCard extends StatelessWidget {
  const _CreatorCard({
    required this.name,
    required this.role,
    required this.caption,
  });

  final String name;
  final String role;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            color: MurkotColors.pulp.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: MurkotColors.orange.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_outline,
                size: 64,
                color: MurkotColors.orange.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 8),
              Text(
                caption,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          role,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}
