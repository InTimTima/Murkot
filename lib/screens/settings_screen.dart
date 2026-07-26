import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/blacklist_service.dart';
import '../services/settings_service.dart';
import '../widgets/confirm_dialogs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settingsService,
    required this.blacklistService,
  });

  final SettingsService settingsService;
  final BlacklistService blacklistService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _blacklistExpanded = false;
  bool _personalizationExpanded = false;
  final _labelControllers = <String, TextEditingController>{};

  @override
  void dispose() {
    for (final c in _labelControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String key, String defaultValue) {
    return _labelControllers.putIfAbsent(
      key,
      () => TextEditingController(
        text: widget.settingsService.personalization[key] ?? '',
      ),
    );
  }

  Future<void> _unblockUser(String login) async {
    final strings = context.strings;
    final confirmed = await showConfirmDialog(
      context: context,
      title: strings.unblockUser,
      message: strings.unblockUserConfirm(login),
    );
    if (confirmed == true) {
      await widget.blacklistService.unblockUser(login);
    }
  }

  static const _personalizationFields = [
    (PersonalizationKeys.online, 'В сети / online'),
    (PersonalizationKeys.offline, 'Не в сети / offline'),
    (PersonalizationKeys.typing, 'Печатает / typing'),
    (PersonalizationKeys.chats, 'Чаты / Chats'),
    (PersonalizationKeys.groups, 'Группы / Groups'),
    (PersonalizationKeys.channels, 'Каналы / Channels'),
    (PersonalizationKeys.createChat, 'Создать чат / Create chat'),
    (PersonalizationKeys.createGroup, 'Создать группу / Create group'),
    (PersonalizationKeys.createChannel, 'Создать канал / Create channel'),
    (PersonalizationKeys.message, 'Сообщение / Message'),
    (PersonalizationKeys.info, 'Информация / Info'),
    (PersonalizationKeys.profile, 'Профиль / Profile'),
    (PersonalizationKeys.settings, 'Настройки / Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.settingsTitle)),
      body: ListenableBuilder(
        listenable: Listenable.merge([widget.settingsService, widget.blacklistService]),
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionTitle(title: strings.languageLabel),
              _languageCard(),
              const SizedBox(height: 20),
              _SectionTitle(title: strings.textSize),
              _textSizeCard(),
              const SizedBox(height: 20),
              _SectionTitle(title: strings.theme),
              _themeCard(theme),
              const SizedBox(height: 20),
              _SectionTitle(title: strings.personalization),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.tune, color: theme.colorScheme.primary),
                      title: Text(strings.personalization),
                      subtitle: Text(strings.personalizationHint),
                      trailing: Icon(
                        _personalizationExpanded ? Icons.expand_less : Icons.expand_more,
                      ),
                      onTap: () =>
                          setState(() => _personalizationExpanded = !_personalizationExpanded),
                    ),
                    if (_personalizationExpanded) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            ..._personalizationFields.map((field) {
                              final key = field.$1;
                              final hint = field.$2;
                              final controller = _controllerFor(key, hint);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TextField(
                                  controller: controller,
                                  decoration: InputDecoration(
                                    labelText: hint,
                                    isDense: true,
                                  ),
                                  onSubmitted: (v) =>
                                      widget.settingsService.setPersonalizationLabel(key, v),
                                ),
                              );
                            }),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () async {
                                      for (final field in _personalizationFields) {
                                        await widget.settingsService.setPersonalizationLabel(
                                          field.$1,
                                          _controllerFor(field.$1, field.$2).text,
                                        );
                                      }
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(strings.save)),
                                        );
                                      }
                                    },
                                    child: Text(strings.save),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () async {
                                    await widget.settingsService.resetPersonalization();
                                    for (final c in _labelControllers.values) {
                                      c.clear();
                                    }
                                    setState(() {});
                                  },
                                  child: Text(strings.resetLabels),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionTitle(title: strings.blacklist),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.block, color: theme.colorScheme.error),
                      title: Text(strings.blacklist),
                      subtitle: Text(
                        strings.blacklistCount(widget.blacklistService.blockedUsers.length),
                      ),
                      trailing: Icon(
                        _blacklistExpanded ? Icons.expand_less : Icons.expand_more,
                      ),
                      onTap: () => setState(() => _blacklistExpanded = !_blacklistExpanded),
                    ),
                    if (_blacklistExpanded) ...[
                      const Divider(height: 1),
                      if (widget.blacklistService.blockedUsers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(strings.blacklistEmpty,
                              style: TextStyle(color: Colors.grey.shade600)),
                        )
                      else
                        ...widget.blacklistService.blockedUsers.map(
                          (login) => ListTile(
                            leading: CircleAvatar(child: Text(login[0].toUpperCase())),
                            title: Text(login),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: theme.colorScheme.error),
                              onPressed: () => _unblockUser(login),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _languageCard() {
    return Card(
      child: Column(
        children: [
          RadioListTile<AppLanguage>(
            title: Text(context.strings.languageRu),
            value: AppLanguage.ru,
            groupValue: widget.settingsService.language,
            onChanged: (v) {
              if (v != null) widget.settingsService.setLanguage(v);
            },
          ),
          const Divider(height: 1),
          RadioListTile<AppLanguage>(
            title: Text(context.strings.languageEn),
            value: AppLanguage.en,
            groupValue: widget.settingsService.language,
            onChanged: (v) {
              if (v != null) widget.settingsService.setLanguage(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _textSizeCard() {
    return Card(
      child: Column(
        children: AppTextSize.values.map((size) {
          final label = switch (size) {
            AppTextSize.small => context.strings.textSmall,
            AppTextSize.normal => context.strings.textNormal,
            AppTextSize.large => context.strings.textLarge,
          };
          return Column(
            children: [
              if (size != AppTextSize.small) const Divider(height: 1),
              RadioListTile<AppTextSize>(
                title: Text(label),
                value: size,
                groupValue: widget.settingsService.textSize,
                onChanged: (v) {
                  if (v != null) widget.settingsService.setTextSize(v);
                },
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _themeCard(ThemeData theme) {
    return Card(
      child: Column(
        children: [
          RadioListTile<ThemeMode>(
            title: Text(context.strings.themeSystem),
            value: ThemeMode.system,
            groupValue: widget.settingsService.themeMode,
            onChanged: (v) {
              if (v != null) widget.settingsService.setThemeMode(v);
            },
          ),
          const Divider(height: 1),
          RadioListTile<ThemeMode>(
            title: Text(context.strings.themeLight),
            value: ThemeMode.light,
            groupValue: widget.settingsService.themeMode,
            onChanged: (v) {
              if (v != null) widget.settingsService.setThemeMode(v);
            },
          ),
          const Divider(height: 1),
          RadioListTile<ThemeMode>(
            title: Text(context.strings.themeDark),
            value: ThemeMode.dark,
            groupValue: widget.settingsService.themeMode,
            onChanged: (v) {
              if (v != null) widget.settingsService.setThemeMode(v);
            },
          ),
        ],
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
