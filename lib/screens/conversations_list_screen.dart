import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/conversation.dart';
import '../services/blacklist_service.dart';
import '../services/chat_service.dart';
import '../services/settings_service.dart';
import '../widgets/avatar_display.dart';
import '../widgets/confirm_dialogs.dart';
import '../widgets/conversation_list_tile.dart';
import '../widgets/section_search_bar.dart';
import 'chat_screen.dart';
import 'stranger_profile_screen.dart';

class ConversationsListScreen extends StatefulWidget {
  const ConversationsListScreen({
    super.key,
    required this.type,
    required this.chatService,
    required this.blacklistService,
    required this.currentUserLogin,
    required this.settingsService,
  });

  final ConversationType type;
  final ChatService chatService;
  final BlacklistService blacklistService;
  final String currentUserLogin;
  final SettingsService settingsService;

  @override
  State<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _sectionIndex => switch (widget.type) {
        ConversationType.direct => 0,
        ConversationType.group => 1,
        ConversationType.channel => 2,
      };

  Future<void> _createNew() async {
    final strings = context.strings;
    final name = await showTextInputDialog(
      context: context,
      title: createDialogTitleForSection(strings, _sectionIndex),
      hint: createDialogHintForSection(strings, _sectionIndex),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return strings.nameRequired;
        }
        return null;
      },
    );

    if (name == null || !mounted) return;

    final conversation = await widget.chatService.createConversation(
      type: widget.type,
      name: name.trim(),
    );

    if (!mounted) return;
    _openChat(conversation);
  }

  void _openChat(Conversation conversation) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ChatScreen(
          conversation: conversation,
          chatService: widget.chatService,
          blacklistService: widget.blacklistService,
          currentUserLogin: widget.currentUserLogin,
          settingsService: widget.settingsService,
        ),
      ),
    );
  }

  void _openProfile(Conversation conversation) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => StrangerProfileScreen(
          conversation: conversation,
          chatService: widget.chatService,
          blacklistService: widget.blacklistService,
          currentUserLogin: widget.currentUserLogin,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return ListenableBuilder(
      listenable: widget.chatService,
      builder: (context, _) {
        final conversations = widget.chatService.searchConversations(
          widget.type,
          _query,
        );

        return Column(
          children: [
            SectionSearchBar(
              controller: _searchController,
              hint: searchHintForSection(strings, _sectionIndex),
              onChanged: (value) => setState(() => _query = value),
            ),
            Expanded(
              child: conversations.isEmpty
                  ? Center(
                      child: Text(
                        strings.emptyList,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      itemCount: conversations.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 72,
                        color: Colors.grey.shade200,
                      ),
                      itemBuilder: (context, index) {
                        final conversation = conversations[index];
                        return ConversationListTile(
                          conversation: conversation,
                          onTapBody: () => _openChat(conversation),
                          onTapAvatar: () => _openProfile(conversation),
                        );
                      },
                    ),
            ),
            _StickyCreateButton(
              label: createLabelForSection(strings, _sectionIndex),
              onPressed: _createNew,
            ),
          ],
        );
      },
    );
  }
}

class _StickyCreateButton extends StatelessWidget {
  const _StickyCreateButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 4,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
