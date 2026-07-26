import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settingsService});

  final SettingsService settingsService;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.settings),
      ),
      body: ListenableBuilder(
        listenable: settingsService,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionTitle(title: strings.languageLabel),
              Card(
                child: Column(
                  children: [
                    RadioListTile<AppLanguage>(
                      title: Text(strings.languageRu),
                      value: AppLanguage.ru,
                      groupValue: settingsService.language,
                      onChanged: (value) {
                        if (value != null) settingsService.setLanguage(value);
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<AppLanguage>(
                      title: Text(strings.languageEn),
                      value: AppLanguage.en,
                      groupValue: settingsService.language,
                      onChanged: (value) {
                        if (value != null) settingsService.setLanguage(value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionTitle(title: strings.textSize),
              Card(
                child: Column(
                  children: [
                    RadioListTile<AppTextSize>(
                      title: Text(strings.textSmall),
                      value: AppTextSize.small,
                      groupValue: settingsService.textSize,
                      onChanged: (value) {
                        if (value != null) settingsService.setTextSize(value);
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<AppTextSize>(
                      title: Text(strings.textNormal),
                      value: AppTextSize.normal,
                      groupValue: settingsService.textSize,
                      onChanged: (value) {
                        if (value != null) settingsService.setTextSize(value);
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<AppTextSize>(
                      title: Text(strings.textLarge),
                      value: AppTextSize.large,
                      groupValue: settingsService.textSize,
                      onChanged: (value) {
                        if (value != null) settingsService.setTextSize(value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionTitle(title: strings.theme),
              Card(
                child: Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      title: Text(strings.themeSystem),
                      secondary: Icon(Icons.brightness_auto, color: theme.colorScheme.primary),
                      value: ThemeMode.system,
                      groupValue: settingsService.themeMode,
                      onChanged: (value) {
                        if (value != null) settingsService.setThemeMode(value);
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<ThemeMode>(
                      title: Text(strings.themeLight),
                      secondary: Icon(Icons.light_mode, color: theme.colorScheme.primary),
                      value: ThemeMode.light,
                      groupValue: settingsService.themeMode,
                      onChanged: (value) {
                        if (value != null) settingsService.setThemeMode(value);
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<ThemeMode>(
                      title: Text(strings.themeDark),
                      secondary: Icon(Icons.dark_mode, color: theme.colorScheme.primary),
                      value: ThemeMode.dark,
                      groupValue: settingsService.themeMode,
                      onChanged: (value) {
                        if (value != null) settingsService.setThemeMode(value);
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
