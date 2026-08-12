import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_strings.dart';
import '../models/media_payload.dart';
import '../models/message.dart';
import '../services/auth_service.dart';
import '../services/blacklist_service.dart';
import '../services/chat_service.dart';
import '../services/listings_service.dart';
import '../services/match_service.dart';
import '../services/notification_service.dart';
import '../services/presence_service.dart';
import '../services/projects_service.dart';
import '../services/settings_service.dart';
import '../utils/main_tab_bus.dart';
import '../widgets/avatar_display.dart';
import '../widgets/command_palette.dart';
import '../widgets/session_boot.dart';
import 'board_screen.dart';
import 'messages_hub_screen.dart';
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
  final Set<int> _builtTabs = {MainTabs.board};
  ChatService? _chatService;
  ListingsService? _listingsService;
  ProjectsService? _projectsService;
  MatchService? _matchService;
  BlacklistService? _blacklistService;
  PresenceService? _presenceService;
  final _notificationService = NotificationService();
  String? _loadError;
  bool _loadingData = false;
  bool _showBoot = true;
  bool _bootFailed = false;
  bool _retriedInit = false;
  DateTime? _bootStartedAt;

  @override
  void initState() {
    super.initState();
    mainTabIndex.addListener(_onExternalTabChange);
    _initServices();
  }

  void _onExternalTabChange() {
    if (!mounted) return;
    final next = mainTabIndex.value;
    if (_currentIndex == next && _builtTabs.contains(next)) return;
    setState(() {
      _builtTabs.add(next);
      _currentIndex = next;
    });
  }

  void _selectTab(int index) {
    mainTabIndex.value = index;
    setState(() {
      _builtTabs.add(index);
      _currentIndex = index;
    });
  }

  void _disposeSessionServices() {
    _chatService?.dispose();
    _presenceService?.dispose();
    _listingsService?.dispose();
    _projectsService?.dispose();
    _matchService?.dispose();
    _blacklistService?.dispose();
    _chatService = null;
    _presenceService = null;
    _listingsService = null;
    _projectsService = null;
    _matchService = null;
    _blacklistService = null;
  }

  /// Best-effort token refresh. Never block the boot screen for long —
  /// web often hangs on refresh when Supabase is unreachable.
  Future<void> _ensureFreshSession() async {
    try {
      final auth = Supabase.instance.client.auth;
      if (auth.currentSession == null) return;
      await auth.refreshSession().timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Session refresh failed: $e');
    }
  }

  Future<void> _initServices() async {
    final user = widget.authService.currentUser;
    if (user == null) return;

    // Dispose previous attempt (e.g. after "Retry").
    _disposeSessionServices();

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

    if (!mounted) {
      chatService.dispose();
      presenceService.dispose();
      return;
    }

    // Show the shell under a boot overlay — chats hydrate in the background.
    setState(() {
      _chatService = chatService;
      _listingsService = ListingsService(userId: user.id);
      _projectsService = ProjectsService(userId: user.id);
      _matchService = MatchService();
      _blacklistService = blacklistService;
      _presenceService = presenceService;
      _loadError = null;
      _loadingData = true;
      _showBoot = true;
      _bootFailed = false;
      _bootStartedAt = DateTime.now();
    });

    unawaited(_notificationService.initialize());
    unawaited(
      _hydrateServices(chatService, blacklistService, presenceService),
    );
  }

  Future<void> _dismissBoot({bool failed = false}) async {
    final started = _bootStartedAt ?? DateTime.now();
    const minShow = Duration(milliseconds: 900);
    final elapsed = DateTime.now().difference(started);
    if (!failed && elapsed < minShow) {
      await Future<void>.delayed(minShow - elapsed);
    }
    if (!mounted) return;
    setState(() {
      if (failed) {
        _bootFailed = true;
        _showBoot = true;
      } else {
        _bootFailed = false;
        _showBoot = false;
      }
    });
  }

  void _openWorkspaceAnyway() {
    if (!mounted) return;
    setState(() {
      _showBoot = false;
      _bootFailed = false;
      _loadingData = false;
    });
  }

  void _retryBoot() {
    _retriedInit = false;
    _initServices();
  }

  Future<void> _hydrateServices(
    ChatService chatService,
    BlacklistService blacklistService,
    PresenceService presenceService,
  ) async {
    // Refresh in parallel with data load — don't serialize a slow timeout.
    final refresh = _ensureFreshSession();

    try {
      await Future.wait([
        refresh,
        blacklistService.initialize().catchError((Object e) {
          debugPrint('Blacklist init failed: $e');
        }),
        chatService.initialize(),
      ]).timeout(const Duration(seconds: 8));

      if (!mounted || !identical(_chatService, chatService)) return;
      setState(() {
        _loadingData = false;
        _loadError = null;
        _bootFailed = false;
      });
      unawaited(presenceService.initialize());
      unawaited(_dismissBoot());
    } catch (e) {
      debugPrint('Hydrate services failed: $e');
      if (!mounted || !identical(_chatService, chatService)) return;

      // One quick retry, then surface the failure on the boot screen.
      if (!_retriedInit) {
        _retriedInit = true;
        await Future<void>.delayed(const Duration(milliseconds: 800));
        if (mounted && identical(_chatService, chatService)) {
          await _hydrateServices(
            chatService,
            blacklistService,
            presenceService,
          );
        }
        return;
      }

      setState(() {
        _loadingData = false;
        _loadError = e.toString();
      });
      unawaited(_dismissBoot(failed: true));
    }
  }

  @override
  void dispose() {
    mainTabIndex.removeListener(_onExternalTabChange);
    _disposeSessionServices();
    super.dispose();
  }

  String get _sectionTitle {
    final strings = context.strings;
    return switch (_currentIndex) {
      MainTabs.board => strings.listingsTab,
      MainTabs.chats => strings.messagesTab,
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
    final listingsService = _listingsService;
    final projectsService = _projectsService;
    final matchService = _matchService;
    final blacklistService = _blacklistService;
    final presenceService = _presenceService;

    if (chatService == null ||
        listingsService == null ||
        projectsService == null ||
        matchService == null ||
        blacklistService == null ||
        presenceService == null) {
      return Scaffold(
        body: SessionBootOverlay(
          failed: _bootFailed,
          onOpenWorkspace: _bootFailed ? _openWorkspaceAnyway : null,
          onRetry: _bootFailed ? _retryBoot : null,
        ),
      );
    }

    final user = widget.authService.currentUser!;
    final theme = Theme.of(context);

    final shell = Scaffold(
      appBar: _currentIndex == MainTabs.profile
          ? null
          : AppBar(
              title: Text(_sectionTitle),
              actions: [
                IconButton(
                  tooltip: strings.cmdShortcutHint,
                  onPressed: () => showCommandPalette(
                    context: context,
                    chatService: chatService,
                  ),
                  icon: const Icon(Icons.search_rounded),
                ),
              ],
              bottom: _loadingData && !_showBoot
                  ? const PreferredSize(
                      preferredSize: Size.fromHeight(3),
                      child: LinearProgressIndicator(minHeight: 3),
                    )
                  : null,
            ),
      body: Column(
        children: [
          if (_loadError != null && !_showBoot)
            Material(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off,
                        color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        strings.chatsLoadFailed,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _retriedInit = false;
                        _initServices();
                      },
                      child: Text(strings.retry),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _builtTabs.contains(MainTabs.board)
                    ? BoardScreen(
                        listingsService: listingsService,
                        projectsService: projectsService,
                        matchService: matchService,
                        chatService: chatService,
                        blacklistService: blacklistService,
                        presenceService: presenceService,
                        currentUserLogin: login,
                        settingsService: widget.settingsService,
                        authService: widget.authService,
                      )
                    : const SizedBox.shrink(),
                _builtTabs.contains(MainTabs.chats)
                    ? MessagesHubScreen(
                        chatService: chatService,
                        blacklistService: blacklistService,
                        presenceService: presenceService,
                        currentUserLogin: login,
                        settingsService: widget.settingsService,
                      )
                    : const SizedBox.shrink(),
                _builtTabs.contains(MainTabs.profile)
                    ? ProfileScreen(
                        authService: widget.authService,
                        settingsService: widget.settingsService,
                        blacklistService: blacklistService,
                      )
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _showBoot
          ? null
          : _CustomBottomNav(
              currentIndex: _currentIndex,
              onTap: _selectTab,
              boardLabel: strings.listingsTab,
              chatsLabel: strings.messagesTab,
              profileLabel: strings.profile,
              profileLogin: user.login,
              profileAvatarPath: user.avatarPath,
              profileAvatarEmoji: user.avatarEmoji,
            ),
    );

    final content = Stack(
      fit: StackFit.expand,
      children: [
        shell,
        if (_showBoot)
          AnimatedOpacity(
            opacity: _showBoot ? 1 : 0,
            duration: const Duration(milliseconds: 320),
            child: SessionBootOverlay(
              failed: _bootFailed,
              onOpenWorkspace: _bootFailed ? _openWorkspaceAnyway : null,
              onRetry: _bootFailed ? _retryBoot : null,
            ),
          ),
      ],
    );

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _OpenCommandPaletteIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _OpenCommandPaletteIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _OpenCommandPaletteIntent: CallbackAction<_OpenCommandPaletteIntent>(
            onInvoke: (_) {
              if (_showBoot || _chatService == null) return null;
              showCommandPalette(
                context: context,
                chatService: _chatService!,
              );
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: content,
        ),
      ),
    );
  }
}

class _OpenCommandPaletteIntent extends Intent {
  const _OpenCommandPaletteIntent();
}

class _CustomBottomNav extends StatelessWidget {
  const _CustomBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.boardLabel,
    required this.chatsLabel,
    required this.profileLabel,
    required this.profileLogin,
    this.profileAvatarPath,
    this.profileAvatarEmoji,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final String boardLabel;
  final String chatsLabel;
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
                      icon: Icons.grid_view_outlined,
                      selectedIcon: Icons.grid_view_rounded,
                      label: boardLabel,
                      isSelected: currentIndex == MainTabs.board,
                      onTap: () => onTap(MainTabs.board),
                    ),
                    _NavItem(
                      icon: Icons.chat_bubble_outline,
                      selectedIcon: Icons.chat_bubble,
                      label: chatsLabel,
                      isSelected: currentIndex == MainTabs.chats,
                      onTap: () => onTap(MainTabs.chats),
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
                  isSelected: currentIndex == MainTabs.profile,
                  onTap: () => onTap(MainTabs.profile),
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
