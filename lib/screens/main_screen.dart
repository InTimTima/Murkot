import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../models/conversation.dart';
import '../models/media_payload.dart';
import '../models/message.dart';
import '../services/auth_service.dart';
import '../services/blacklist_service.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../services/presence_service.dart';
import '../services/settings_service.dart';
import '../utils/main_tab_bus.dart';
import '../widgets/avatar_display.dart';
import 'conversations_list_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.authService,
    required this.settingsService,
    required this.prefs,
  });

  final AuthService authService;
  final SettingsService settingsService;
  final SharedPreferences prefs;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  ChatService? _chatService;
  BlacklistService? _blacklistService;
  PresenceService? _presenceService;
  final _notificationService = NotificationService();
  String? _loadError;

  @override
  void initState() {
    super.initState();
    mainTabIndex.addListener(_onExternalTabChange);
    _initServices();
  }

  void _onExternalTabChange() {
    if (!mounted || _currentIndex == mainTabIndex.value) return;
    setState(() => _currentIndex = mainTabIndex.value);
  }

  Future<void> _initServices() async {
    final user = widget.authService.currentUser;
    if (user == null) return;

    final blacklistService =
        BlacklistService(userId: user.id, userLogin: user.login);
    final presenceService = PresenceService(
      userId: user.id,
      userLogin: user.login,
    );
    final chatService = ChatService(
      userId: user.id,
      userLogin: user.login,
      prefs: widget.prefs,
      blacklistService: blacklistService,
    );
    chatService.onIncomingMessage = (message, conversation) {
      final body = message.type == MessageType.text
          ? message.content
          : (MediaPayload.tryParse(message.content)?.name ??
              messageTypeLabel(message.type));
      _notificationService.showIncomingMessage(
        title: conversation.name,
        body: '${message.senderName}: $body',
        conversationId: conversation.id,
      );
    };

    try {
      // Load chats + blacklist in parallel; never block UI on push permission.
      await Future.wait([
        blacklistService.initialize(),
        chatService.initialize(),
      ]).timeout(const Duration(seconds: 12));

      if (!mounted) {
        chatService.dispose();
        presenceService.dispose();
        return;
      }
      setState(() {
        _chatService = chatService;
        _blacklistService = blacklistService;
        _presenceService = presenceService;
        _loadError = null;
      });

      unawaited(presenceService.initialize());
      unawaited(_notificationService.initialize());
    } catch (e) {
      chatService.dispose();
      presenceService.dispose();
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    }
  }

  @override
  void dispose() {
    mainTabIndex.removeListener(_onExternalTabChange);
    _chatService?.dispose();
    _presenceService?.dispose();
    super.dispose();
  }

  String get _sectionTitle {
    final strings = context.strings;
    return switch (_currentIndex) {
      0 => strings.chats,
      1 => strings.groups,
      2 => strings.channels,
      _ => strings.profile,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.authService,
      builder: (context, _) => _buildShell(context),
    );
  }

  Widget _buildShell(BuildContext context) {
    final strings = context.strings;
    final login = widget.authService.currentUser!.login;
    final chatService = _chatService;
    final blacklistService = _blacklistService;
    final presenceService = _presenceService;

    if (_loadError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Не удалось загрузить данные',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() => _loadError = null);
                    _initServices();
                  },
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (chatService == null ||
        blacklistService == null ||
        presenceService == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = widget.authService.currentUser!;

    return Scaffold(
      appBar: _currentIndex == 3 ? null : AppBar(title: Text(_sectionTitle)),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ConversationsListScreen(
            type: ConversationType.direct,
            chatService: chatService,
            blacklistService: blacklistService,
            presenceService: presenceService,
            currentUserLogin: login,
            settingsService: widget.settingsService,
          ),
          ConversationsListScreen(
            type: ConversationType.group,
            chatService: chatService,
            blacklistService: blacklistService,
            presenceService: presenceService,
            currentUserLogin: login,
            settingsService: widget.settingsService,
          ),
          ConversationsListScreen(
            type: ConversationType.channel,
            chatService: chatService,
            blacklistService: blacklistService,
            presenceService: presenceService,
            currentUserLogin: login,
            settingsService: widget.settingsService,
          ),
          ProfileScreen(
            authService: widget.authService,
            settingsService: widget.settingsService,
            blacklistService: blacklistService,
          ),
        ],
      ),
      bottomNavigationBar: _CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          mainTabIndex.value = index;
          setState(() => _currentIndex = index);
        },
        chatsLabel: strings.chats,
        groupsLabel: strings.groups,
        channelsLabel: strings.channels,
        profileLabel: strings.profile,
        profileLogin: user.login,
        profileAvatarPath: user.avatarPath,
        profileAvatarEmoji: user.avatarEmoji,
      ),
    );
  }
}

class _CustomBottomNav extends StatelessWidget {
  const _CustomBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.chatsLabel,
    required this.groupsLabel,
    required this.channelsLabel,
    required this.profileLabel,
    required this.profileLogin,
    this.profileAvatarPath,
    this.profileAvatarEmoji,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final String chatsLabel;
  final String groupsLabel;
  final String channelsLabel;
  final String profileLabel;
  final String profileLogin;
  final String? profileAvatarPath;
  final String? profileAvatarEmoji;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _NavItem(
                      icon: Icons.chat_bubble_outline,
                      selectedIcon: Icons.chat_bubble,
                      label: chatsLabel,
                      isSelected: currentIndex == 0,
                      onTap: () => onTap(0),
                    ),
                    _NavItem(
                      icon: Icons.group_outlined,
                      selectedIcon: Icons.group,
                      label: groupsLabel,
                      isSelected: currentIndex == 1,
                      onTap: () => onTap(1),
                    ),
                    _NavItem(
                      icon: Icons.campaign_outlined,
                      selectedIcon: Icons.campaign,
                      label: channelsLabel,
                      isSelected: currentIndex == 2,
                      onTap: () => onTap(2),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: Colors.grey.shade400,
              ),
              SizedBox(
                width: 88,
                child: _ProfileNavItem(
                  label: profileLabel,
                  login: profileLogin,
                  avatarPath: profileAvatarPath,
                  avatarEmoji: profileAvatarEmoji,
                  isSelected: currentIndex == 3,
                  onTap: () => onTap(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Profile nav item: label on top, current account avatar below, nick at
/// the bottom — shows which account is active without opening the profile.
class _ProfileNavItem extends StatelessWidget {
  const _ProfileNavItem({
    required this.label,
    required this.login,
    required this.isSelected,
    required this.onTap,
    this.avatarPath,
    this.avatarEmoji,
  });

  final String label;
  final String login;
  final bool isSelected;
  final VoidCallback onTap;
  final String? avatarPath;
  final String? avatarEmoji;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        isSelected ? theme.colorScheme.primary : Colors.grey.shade600;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Container(
              decoration: isSelected
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary,
                        width: 1.5,
                      ),
                    )
                  : null,
              child: AvatarDisplay(
                name: login,
                avatarPath: avatarPath,
                avatarEmoji: avatarEmoji,
                radius: 13,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              login,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isSelected
        ? theme.colorScheme.primary
        : Colors.grey.shade600;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelected ? selectedIcon : icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
