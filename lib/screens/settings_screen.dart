import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/blacklist_service.dart';
import '../services/moderation_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../utils/admin.dart';
import '../widgets/confirm_dialogs.dart';
import '../widgets/unlumen/murkot_fx.dart';
import 'admin_panel_screen.dart';
import 'moderation_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settingsService,
    required this.blacklistService,
    this.authService,
  });

  final SettingsService settingsService;
  final BlacklistService blacklistService;
  final AuthService? authService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _blacklistExpanded = false;
  bool _personalizationExpanded = false;
  bool _interfaceExpanded = false;
  final _labelControllers = <String, TextEditingController>{};
  final _moderationService = ModerationService();
  final _adminService = AdminService();
  bool _moderatorChecked = false;
  bool _adminChecked = false;

  @override
  void initState() {
    super.initState();
    final login = widget.authService?.currentUser?.login;
    _moderationService.checkModerator().then((_) {
      if (mounted) setState(() => _moderatorChecked = true);
    });
    _adminService.checkAdmin(login: login).then((_) {
      if (mounted) setState(() => _adminChecked = true);
    });
  }

  @override
  void dispose() {
    for (final c in _labelControllers.values) {
      c.dispose();
    }
    _moderationService.dispose();
    _adminService.dispose();
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
    (PersonalizationKeys.circleVideo, 'Кружок / Circle'),
    (PersonalizationKeys.stickers, 'Стикеры / Stickers'),
    (PersonalizationKeys.gif, 'GIF / GIF'),
    (PersonalizationKeys.emoji, 'Эмодзи / Emoji'),
    (PersonalizationKeys.voiceNote, 'Голосовое / Voice note'),
  ];

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const MurkotBackButton(),
        title: Text(strings.settingsTitle),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge(
            [widget.settingsService, widget.blacklistService]),
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
              _SectionTitle(title: strings.notifications),
              Card(
                child: ListTile(
                  leading: Icon(Icons.notifications_outlined,
                      color: theme.colorScheme.primary),
                  title: Text(strings.notificationsMessages),
                  subtitle: Text(
                    '${strings.notificationsHint}\n${strings.notificationsAndroidHint}',
                  ),
                  trailing: MurkotSwitch(
                    value: widget.settingsService.notificationsEnabled,
                    onChanged: (v) async {
                      final notifications = NotificationService(
                        settings: widget.settingsService,
                      );
                      await notifications.setUserEnabled(v);
                      if (!mounted) return;
                      setState(() {});
                      final strings = context.strings;
                      if (v) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              notifications.isEnabled
                                  ? strings.notificationsEnabledDone
                                  : strings.notificationsDenied,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
              if (_adminChecked &&
                  (_adminService.isAdmin == true ||
                      isMurkotAdminLogin(
                          widget.authService?.currentUser?.login))) ...[
                const SizedBox(height: 20),
                _SectionTitle(title: strings.adminTitle),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.admin_panel_settings_outlined,
                        color: theme.colorScheme.primary),
                    title: Text(strings.adminTitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AdminPanelScreen(
                            currentLogin:
                                widget.authService?.currentUser?.login,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (_moderatorChecked &&
                  _moderationService.isModerator == true) ...[
                const SizedBox(height: 20),
                _SectionTitle(title: strings.moderationTitle),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.gavel_outlined,
                        color: theme.colorScheme.primary),
                    title: Text(strings.moderationTitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ModerationScreen(
                            moderationService: _moderationService,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _SectionTitle(title: strings.interfaceSection),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.display_settings_outlined,
                          color: theme.colorScheme.primary),
                      title: Text(strings.interfaceSection),
                      subtitle: Text(strings.interfaceSectionHint),
                      trailing: Icon(
                        _interfaceExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                      ),
                      onTap: () => setState(
                          () => _interfaceExpanded = !_interfaceExpanded),
                    ),
                    if (_interfaceExpanded) ...[
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: Icon(Icons.tips_and_updates_outlined,
                            color: theme.colorScheme.primary),
                        title: Text(strings.floatingTooltips),
                        subtitle: Text(strings.floatingTooltipsHint),
                        value: widget.settingsService.floatingTooltips,
                        onChanged: widget.settingsService.setFloatingTooltips,
                      ),
                      SwitchListTile(
                        secondary: Icon(Icons.auto_awesome_outlined,
                            color: theme.colorScheme.primary),
                        title: Text(strings.authSpotlight),
                        subtitle: Text(strings.authSpotlightHint),
                        value: widget.settingsService.authSpotlight,
                        onChanged: widget.settingsService.setAuthSpotlight,
                      ),
                      SwitchListTile(
                        secondary: Icon(Icons.animation_outlined,
                            color: theme.colorScheme.primary),
                        title: Text(strings.smoothTheme),
                        subtitle: Text(strings.smoothThemeHint),
                        value: widget.settingsService.smoothTheme,
                        onChanged: widget.settingsService.setSmoothTheme,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionTitle(title: strings.personalization),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.tune,
                          color: theme.colorScheme.primary),
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
    final size = widget.settingsService.textSize;
    final value = switch (size) {
      AppTextSize.small => 0.0,
      AppTextSize.normal => 1.0,
      AppTextSize.large => 2.0,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.strings.textSmall),
                Text(context.strings.textNormal),
                Text(context.strings.textLarge),
              ],
            ),
            MurkotSlider(
              value: value,
              min: 0,
              max: 2,
              divisions: 2,
              onChanged: (v) {
                final next = switch (v.round()) {
                  0 => AppTextSize.small,
                  2 => AppTextSize.large,
                  _ => AppTextSize.normal,
                };
                widget.settingsService.setTextSize(next);
              },
            ),
          ],
        ),
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
