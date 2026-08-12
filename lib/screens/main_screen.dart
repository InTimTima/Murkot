import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
import '../widgets/murkot_decor.dart';
import '../widgets/unlumen/murkot_fx.dart';
import 'about_murkot_screen.dart';
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
  bool _initRunning = false;

  static const _maxInitAttempts = 3;

  @override
  void initState() {
    super.initState();
    _notificationService.attachSettings(widget.settingsService);
    mainTabIndex.addListener(_onExternalTabChange);
    _initServices();
  }

  void _onExternalTabChange() {
    if (!mounted || _currentIndex == mainTabIndex.value) return;
    setState(() => _currentIndex = mainTabIndex.value);
  }

  /// Refreshes the stored auth token before data queries. Returns false when
  /// the session is beyond recovery (dead refresh token) and the user must
  /// log in again.
  Future<bool> _ensureFreshSession({bool force = false}) async {
    final auth = Supabase.instance.client.auth;
    final session = auth.currentSession;
    if (session == null) return false;

    // Refresh proactively when the token is expired or about to expire, so
    // the batch of startup queries never runs with a stale JWT.
    final expiresAt = session.expiresAt;
    final expiresSoon = session.isExpired ||
        (expiresAt != null &&
            DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000)
                    .difference(DateTime.now()) <
                const Duration(minutes: 2));
    if (!force && !expiresSoon) return true;

    try {
      await auth.refreshSession().timeout(const Duration(seconds: 10));
      return true;
    } on AuthException catch (e) {
      debugPrint('Session refresh rejected: ${e.message}');
      // Invalid/expired refresh token — a retry will never succeed.
      return false;
    } catch (e) {
      // Network hiccup: not fatal, the attempt loop will retry.
      debugPrint('Session refresh failed: $e');
      return true;
    }
  }

  bool _looksLikeAuthError(Object e) {
    if (e is AuthException) return true;
    final text = e.toString().toLowerCase();
    return text.contains('jwt') ||
        text.contains('401') ||
        text.contains('refresh_token') ||
        text.contains('invalid_grant') ||
        text.contains('pgrst301');
  }

  Future<void> _forceRelogin() async {
    debugPrint('Session is not recoverable, signing out.');
    await widget.authService.logout();
  }

  String _friendlyLoadError(Object e) {
    if (e is TimeoutException) {
      return context.strings.serverTimeout;
    }
    return e.toString();
  }

  Future<void> _initServices() async {
    if (_initRunning) return;
    _initRunning = true;
    try {
      await _runInitAttempts();
    } finally {
      _initRunning = false;
    }
  }

  Future<void> _runInitAttempts() async {
    for (var attempt = 1; attempt <= _maxInitAttempts; attempt++) {
      final user = widget.authService.currentUser;
      if (user == null || !mounted) return;

      // On retries force a token refresh: the most common reason the first
      // attempt fails after a long idle period is a stale JWT.
      final sessionOk = await _ensureFreshSession(force: attempt > 1);
      if (!sessionOk) {
        await _forceRelogin();
        return;
      }

      final error = await _tryInitOnce(user, attempt);
      if (error == null) return; // success

      if (_looksLikeAuthError(error)) {
        // Token is rejected even after refresh — session is broken,
        // re-login instead of hanging forever.
        await _forceRelogin();
        return;
      }

      if (attempt < _maxInitAttempts) {
        await Future<void>.delayed(Duration(seconds: 2 * attempt));
        continue;
      }

      if (mounted) {
        setState(() => _loadError = _friendlyLoadError(error));
      }
    }
  }

  /// One full init attempt. Returns null on success, the error otherwise.
  Future<Object?> _tryInitOnce(dynamic user, int attempt) async {
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
      // Give later attempts more time: after DB updates or a cold start the
      // backend may answer slowly on the first requests.
      await Future.wait([
        blacklistService.initialize(),
        chatService.initialize(),
      ]).timeout(Duration(seconds: 12 + 8 * (attempt - 1)));

      if (!mounted) {
        chatService.dispose();
        presenceService.dispose();
        return null;
      }
      setState(() {
        _chatService = chatService;
        _blacklistService = blacklistService;
        _presenceService = presenceService;
        _loadError = null;
      });

      unawaited(presenceService.initialize());
      unawaited(_notificationService.initialize());
      return null;
    } catch (e) {
      chatService.dispose();
      presenceService.dispose();
      return e;
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
    final currentUser = widget.authService.currentUser;
    // During a forced re-login the auth screen replaces this widget on the
    // next frame; render a placeholder instead of crashing on null.
    if (currentUser == null) {
      return const Scaffold(body: Center(child: MurkotLoader(size: 48)));
    }
    final login = currentUser.login;
    final chatService = _chatService;
    final blacklistService = _blacklistService;
    final presenceService = _presenceService;

    if (_loadError != null) {
      final strings = context.strings;
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  strings.loadFailed,
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
                  child: Text(strings.retry),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => widget.authService.logout(),
                  child: Text(strings.logout),
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
        body: ConversationListSkeleton(),
      );
    }

    final user = widget.authService.currentUser!;

    return Scaffold(
      appBar: _currentIndex == 3
          ? null
          : AppBar(
              title: Text(_sectionTitle),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: MurkotThemeSwitch(
                      settings: widget.settingsService,
                    ),
                  ),
                ),
              ],
            ),
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
        settingsService: widget.settingsService,
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
    required this.settingsService,
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
  final SettingsService settingsService;
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
          height: 80,
          child: Row(
            children: [
              // About Murkot — mark + label, separated like profile.
              SizedBox(
                width: 76,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AboutMurkotScreen(
                            settingsService: settingsService,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const MurkotStackedMark(size: 44),
                        const SizedBox(height: 2),
                        Text(
                          context.strings.aboutUs,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                color: Colors.grey.shade400,
              ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
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
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Material(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
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
        ),
      ),
    );
  }
}
