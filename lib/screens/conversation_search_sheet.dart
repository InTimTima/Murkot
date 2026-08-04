import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/conversation.dart';
import '../models/public_conversation.dart';
import '../services/chat_service.dart';
import '../widgets/avatar_display.dart';

/// Search for public groups/channels; returns the selected preview.
Future<PublicConversationPreview?> showConversationSearchSheet({
  required BuildContext context,
  required ChatService chatService,
  required ConversationType type,
}) {
  return showModalBottomSheet<PublicConversationPreview>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => ConversationSearchSheet(
      chatService: chatService,
      type: type,
    ),
  );
}

class ConversationSearchSheet extends StatefulWidget {
  const ConversationSearchSheet({
    super.key,
    required this.chatService,
    required this.type,
  });

  final ChatService chatService;
  final ConversationType type;

  @override
  State<ConversationSearchSheet> createState() =>
      _ConversationSearchSheetState();
}

class _ConversationSearchSheetState extends State<ConversationSearchSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<PublicConversationPreview> _results = const [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      _search(value);
    });
  }

  Future<void> _search(String value) async {
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results =
          await widget.chatService.searchPublicConversations(q, widget.type);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _results = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final isChannel = widget.type == ConversationType.channel;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                isChannel ? strings.findChannel : strings.findGroup,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: isChannel
                      ? strings.newChannelHint
                      : strings.newGroupHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _controller.clear();
                            _search('');
                            setState(() {});
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: (value) {
                  setState(() {});
                  _onQueryChanged(value);
                },
              ),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const LinearProgressIndicator(minHeight: 2)
            else
              const SizedBox(height: 2),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    )
                  : _controller.text.trim().isEmpty
                      ? Center(
                          child: Text(
                            strings.searchUsersEmptyHint,
                            style: TextStyle(color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : _results.isEmpty && !_loading
                          ? Center(
                              child: Text(
                                strings.nothingFound,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _results.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                indent: 72,
                                color: Colors.grey.shade200,
                              ),
                              itemBuilder: (context, index) {
                                final item = _results[index];
                                return ListTile(
                                  leading: AvatarDisplay(
                                    name: item.name,
                                    avatarPath: item.avatarUrl,
                                    avatarEmoji: item.avatarEmoji,
                                    radius: 22,
                                  ),
                                  title: Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    strings.membersCount(item.memberCount),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: item.isMember
                                      ? Text(
                                          strings.alreadyMember,
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                            color: Colors.grey.shade600,
                                          ),
                                        )
                                      : FilledButton.tonal(
                                          onPressed: () =>
                                              Navigator.pop(context, item),
                                          child: Text(strings.joinAction),
                                        ),
                                  onTap: () => Navigator.pop(context, item),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
