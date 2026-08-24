import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/public_conversation.dart';
import '../services/blacklist_service.dart';
import '../services/chat_service.dart';
import '../services/presence_service.dart';
import '../services/settings_service.dart';
import '../widgets/avatar_display.dart';
import '../widgets/guest_gate.dart';
import '../widgets/murkot_decor.dart';
import 'chat_screen.dart';

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({
    super.key,
    required this.chatService,
    required this.blacklistService,
    required this.presenceService,
    required this.currentUserLogin,
    required this.settingsService,
  });

  final ChatService chatService;
  final BlacklistService blacklistService;
  final PresenceService presenceService;
  final String currentUserLogin;
  final SettingsService settingsService;

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  List<PublicConversationPreview> _channels = const [];
  bool _loading = true;
  String? _error;
  final Set<String> _joining = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final channels = await widget.chatService.listCommunityChannels();
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openOrJoin(PublicConversationPreview preview) async {
    if (!await ensureRegistered(context, settings: widget.settingsService)) {
      return;
    }
    final strings = context.strings;
    final wasMember = preview.isMember;
    setState(() => _joining.add(preview.id));
    try {
      // Idempotent: works both for first join and re-open.
      final conversation =
          await widget.chatService.joinConversation(preview.id);

      if (!mounted) return;
      if (conversation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.openChatFailed)),
        );
        return;
      }

      if (!wasMember) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.communityJoined)),
        );
        await _load();
      }

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
      if (mounted) await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${strings.openChatFailed}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _joining.remove(preview.id));
      }
    }
  }

  String _categoryLabel(AppStrings strings, String? category) {
    switch (category) {
      case 'startup':
        return strings.communityCategoryStartup;
      case 'career':
        return strings.communityCategoryCareer;
      case 'dev':
        return strings.communityCategoryDev;
      case 'creative':
        return strings.communityCategoryCreative;
      default:
        return strings.communityCategoryGeneral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);

    if (_loading && _channels.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.communitiesLoadFailed,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: Text(strings.retry)),
          ],
        ),
      );
    }
    if (_channels.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Stack(
                      alignment: Alignment.center,
                      children: [
                        CitrusSlice(size: 72, opacity: 0.55),
                        StretchCatSilhouette(width: 96, opacity: 0.35),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      strings.communitiesEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final grouped = <String, List<PublicConversationPreview>>{};
    for (final channel in _channels) {
      final key = channel.category ?? 'general';
      grouped.putIfAbsent(key, () => []).add(channel);
    }

    final order = ['startup', 'career', 'dev', 'creative', 'general'];
    final keys = [
      ...order.where(grouped.containsKey),
      ...grouped.keys.where((k) => !order.contains(k)),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              strings.communitiesHint,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
          for (final key in keys) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Text(
                _categoryLabel(strings, key),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final channel in grouped[key]!)
              _CommunityCard(
                channel: channel,
                joining: _joining.contains(channel.id),
                onTap: () => _openOrJoin(channel),
              ),
          ],
        ],
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  const _CommunityCard({
    required this.channel,
    required this.joining,
    required this.onTap,
  });

  final PublicConversationPreview channel;
  final bool joining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: joining ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarDisplay(
                name: channel.name,
                avatarPath: channel.avatarUrl,
                avatarEmoji: channel.avatarEmoji,
                radius: 26,
                fontSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            channel.name,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (channel.isMember)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              strings.alreadyMember,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (channel.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        channel.description,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      strings.membersCount(channel.memberCount),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: joining
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : FilledButton.tonal(
                              onPressed: onTap,
                              child: Text(
                                channel.isMember
                                    ? strings.communityOpen
                                    : strings.communityJoin,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
