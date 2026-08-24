import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/brand_theme.dart';
import '../l10n/app_strings.dart';
import '../models/user.dart';
import '../models/user_preview.dart';
import '../services/blacklist_service.dart';
import '../services/chat_service.dart';
import '../services/presence_service.dart';
import '../services/settings_service.dart';
import '../utils/main_tab_bus.dart';
import '../utils/profile_deep_link.dart';
import '../widgets/avatar_display.dart';
import '../widgets/dev_card.dart';
import '../widgets/dev_status_badge.dart';
import '../widgets/guest_gate.dart';
import '../widgets/report_sheet.dart';
import '../widgets/unlumen/murkot_fx.dart';
import 'chat_screen.dart';

/// Public profile opened via `/@login` (or from an in-app link).
class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({
    super.key,
    required this.login,
    required this.chatService,
    required this.blacklistService,
    required this.presenceService,
    required this.currentUserLogin,
    required this.settingsService,
  });

  final String login;
  final ChatService chatService;
  final BlacklistService blacklistService;
  final PresenceService presenceService;
  final String currentUserLogin;
  final SettingsService settingsService;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  User? _user;
  bool _loading = true;
  bool _notFound = false;
  bool _openingChat = false;

  bool get _isSelf =>
      widget.login.toLowerCase() == widget.currentUserLogin.toLowerCase();

  @override
  void initState() {
    super.initState();
    if (_isSelf) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        mainTabIndex.value = MainTabs.profile;
        Navigator.of(context).pop();
      });
      return;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _notFound = false;
    });
    final profile = await widget.chatService.fetchProfileByLogin(widget.login);
    if (!mounted) return;
    setState(() {
      _user = profile;
      _notFound = profile == null;
      _loading = false;
    });
  }

  Future<void> _copyLink() async {
    final url = buildPublicProfileUrl(widget.login);
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings.profileLinkCopied)),
    );
  }

  Future<void> _message() async {
    if (!await ensureRegistered(context, settings: widget.settingsService)) {
      return;
    }
    final user = _user;
    if (user == null || _openingChat) return;
    setState(() => _openingChat = true);
    try {
      final conversation = await widget.chatService.openDirectChat(
        UserPreview(
          id: user.id,
          login: user.login,
          status: user.status,
          avatarEmoji: user.avatarEmoji,
          avatarUrl: user.avatarPath,
        ),
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => ChatScreen(
            conversation: conversation,
            chatService: widget.chatService,
            blacklistService: widget.blacklistService,
            presenceService: widget.presenceService,
            currentUserLogin: widget.currentUserLogin,
            settingsService: widget.settingsService,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.openChatFailed)),
      );
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  Future<void> _report() async {
    await showReportSheet(
      context: context,
      targetType: 'profile',
      targetId: widget.login,
      targetLabel: '@${widget.login}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final user = _user;

    return Scaffold(
      appBar: AppBar(
        title: Text('@${widget.login}'),
        actions: [
          IconButton(
            tooltip: strings.copyProfileLink,
            onPressed: _copyLink,
            icon: const Icon(Icons.link),
          ),
          if (!_isSelf && !_notFound)
            IconButton(
              tooltip: strings.reportTitle,
              onPressed: _report,
              icon: const Icon(Icons.flag_outlined),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: theme.brightness == Brightness.dark
              ? MurkotColors.authGradientDark
              : MurkotColors.authGradientLight,
        ),
        child: _loading
            ? const Center(child: MurkotLoader(size: 48))
            : _notFound || user == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        strings.userNotFound(widget.login),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      Center(
                        child: AvatarDisplay(
                          name: user.login,
                          avatarPath: user.avatarPath,
                          avatarEmoji: user.avatarEmoji,
                          radius: 48,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user.login,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (user.devStatus != DevStatus.none) ...[
                        const SizedBox(height: 8),
                        Center(child: DevStatusBadge(status: user.devStatus)),
                      ],
                      if (user.status.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          user.status,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (DevCardView.hasContent(user)) ...[
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withValues(
                              alpha: 0.92,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: DevCardView(
                            user: user,
                            showPlaceholderWhenEmpty: false,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _openingChat ? null : _message,
                        icon: _openingChat
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.chat_bubble_outline),
                        label: Text(strings.matchOpenChat),
                      ),
                    ],
                  ),
      ),
    );
  }
}
