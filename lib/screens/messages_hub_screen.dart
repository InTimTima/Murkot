import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/conversation.dart';
import '../services/blacklist_service.dart';
import '../services/chat_service.dart';
import '../services/presence_service.dart';
import '../services/settings_service.dart';
import 'conversations_list_screen.dart';

/// Single Chats tab with filters: DMs / groups / channels.
class MessagesHubScreen extends StatefulWidget {
  const MessagesHubScreen({
    super.key,
    required this.chatService,
    required this.blacklistService,
    required this.presenceService,
    required this.currentUserLogin,
    required this.settingsService,
    this.initialFilter = ConversationType.direct,
  });

  final ChatService chatService;
  final BlacklistService blacklistService;
  final PresenceService presenceService;
  final String currentUserLogin;
  final SettingsService settingsService;
  final ConversationType initialFilter;

  @override
  State<MessagesHubScreen> createState() => _MessagesHubScreenState();
}

class _MessagesHubScreenState extends State<MessagesHubScreen> {
  late ConversationType _filter;
  final Set<ConversationType> _builtFilters = {};

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _builtFilters.add(_filter);
  }

  int get _index => switch (_filter) {
        ConversationType.direct => 0,
        ConversationType.group => 1,
        ConversationType.channel => 2,
      };

  Widget _lazy(ConversationType type, Widget child) {
    if (!_builtFilters.contains(type)) {
      return const SizedBox.shrink();
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: SegmentedButton<ConversationType>(
            segments: [
              ButtonSegment(
                value: ConversationType.direct,
                label: Text(strings.chats),
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
              ),
              ButtonSegment(
                value: ConversationType.group,
                label: Text(strings.groups),
                icon: const Icon(Icons.group_outlined, size: 16),
              ),
              ButtonSegment(
                value: ConversationType.channel,
                label: Text(strings.channels),
                icon: const Icon(Icons.campaign_outlined, size: 16),
              ),
            ],
            selected: {_filter},
            onSelectionChanged: (next) {
              setState(() {
                _filter = next.first;
                _builtFilters.add(_filter);
              });
            },
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _index,
            children: [
              _lazy(
                ConversationType.direct,
                ConversationsListScreen(
                  type: ConversationType.direct,
                  chatService: widget.chatService,
                  blacklistService: widget.blacklistService,
                  presenceService: widget.presenceService,
                  currentUserLogin: widget.currentUserLogin,
                  settingsService: widget.settingsService,
                ),
              ),
              _lazy(
                ConversationType.group,
                ConversationsListScreen(
                  type: ConversationType.group,
                  chatService: widget.chatService,
                  blacklistService: widget.blacklistService,
                  presenceService: widget.presenceService,
                  currentUserLogin: widget.currentUserLogin,
                  settingsService: widget.settingsService,
                ),
              ),
              _lazy(
                ConversationType.channel,
                ConversationsListScreen(
                  type: ConversationType.channel,
                  chatService: widget.chatService,
                  blacklistService: widget.blacklistService,
                  presenceService: widget.presenceService,
                  currentUserLogin: widget.currentUserLogin,
                  settingsService: widget.settingsService,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
