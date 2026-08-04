import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../models/conversation.dart';
import '../models/media_payload.dart';
import '../models/message.dart';
import '../services/blacklist_service.dart';
import '../services/chat_service.dart';
import '../utils/helpers.dart';
import '../widgets/avatar_display.dart' hide pickRandomEmoji;
import '../widgets/confirm_dialogs.dart';
import 'user_search_sheet.dart';

class StrangerProfileScreen extends StatefulWidget {
  const StrangerProfileScreen({
    super.key,
    required this.conversation,
    required this.chatService,
    required this.blacklistService,
    required this.currentUserLogin,
  });

  final Conversation conversation;
  final ChatService chatService;
  final BlacklistService blacklistService;
  final String currentUserLogin;

  @override
  State<StrangerProfileScreen> createState() => _StrangerProfileScreenState();
}

class _StrangerProfileScreenState extends State<StrangerProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Conversation _conversation;

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _isDirect => _conversation.type == ConversationType.direct;
  bool get _isChannel => _conversation.type == ConversationType.channel;
  bool get _isGroup => _conversation.type == ConversationType.group;
  bool get _isBlocked =>
      _isDirect && widget.blacklistService.isBlocked(_conversation.name);

  Future<void> _blockUser() async {
    final strings = context.strings;
    final confirmed = await showConfirmDialog(
      context: context,
      title: strings.blockUser,
      message: strings.blockUserConfirm(_conversation.name),
      isDestructive: true,
    );
    if (confirmed == true) {
      await widget.blacklistService.blockUser(_conversation.name);
      if (mounted) setState(() {});
    }
  }

  Future<void> _unblockUser() async {
    await widget.blacklistService.unblockUser(_conversation.name);
    if (mounted) setState(() {});
  }

  Future<void> _deleteOrLeave() async {
    final strings = context.strings;

    if (_isDirect) {
      final confirmed = await showConfirmDialog(
        context: context,
        title: strings.deleteChat,
        message: strings.deleteChatConfirm,
        isDestructive: true,
      );
      if (confirmed == true) {
        await widget.chatService.deleteConversation(_conversation.id);
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return;
    }

    if (_conversation.isAdmin) {
      final confirmed = await showConfirmDialog(
        context: context,
        title: strings.deleteGroupOrChannel,
        message: strings.deleteGroupOrChannelConfirm(_conversation.name),
        isDestructive: true,
      );
      if (confirmed == true) {
        await widget.chatService.deleteConversation(_conversation.id);
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return;
    }

    final confirmed = await showConfirmDialog(
      context: context,
      title: _isChannel ? strings.leaveChannel : strings.leaveGroup,
      message: _isChannel ? strings.leaveChannelConfirm : strings.leaveGroupConfirm,
      isDestructive: true,
    );
    if (confirmed == true) {
      await widget.chatService.leaveConversation(_conversation.id);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _rename() async {
    final strings = context.strings;
    final name = await showTextInputDialog(
      context: context,
      title: strings.rename,
      hint: strings.nameRequired,
      initialValue: _conversation.name,
      validator: (v) => v == null || v.trim().isEmpty ? strings.nameRequired : null,
    );
    if (name != null) {
      await widget.chatService.updateConversation(_conversation.copyWith(name: name));
      if (mounted) {
        setState(() {
          _conversation = widget.chatService.getConversation(_conversation.id)!;
        });
      }
    }
  }

  Future<void> _manageMembers() async {
    final strings = context.strings;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final conversation = widget.chatService
                    .getConversation(_conversation.id) ??
                _conversation;

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.55,
              minChildSize: 0.3,
              maxChildSize: 0.85,
              builder: (context, scrollController) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      strings.members,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ...conversation.memberIds.map(
                      (member) => ListTile(
                        leading: AvatarDisplay(
                          name: member,
                          avatarEmoji: pickRandomEmoji(member.hashCode),
                          radius: 20,
                        ),
                        title: Text(member),
                        trailing: conversation.isAdmin &&
                                member != widget.currentUserLogin
                            ? IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () async {
                                  try {
                                    await widget.chatService
                                        .removeMemberByLogin(
                                      conversation.id,
                                      member,
                                    );
                                    if (!mounted) return;
                                    setState(() {
                                      _conversation = widget.chatService
                                          .getConversation(conversation.id)!;
                                    });
                                    setSheetState(() {});
                                    ScaffoldMessenger.of(this.context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(strings.memberRemoved),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(this.context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${strings.memberActionFailed}: $e',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              )
                            : null,
                      ),
                    ),
                    if (conversation.isAdmin) ...[
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.person_add_outlined),
                        title: Text(strings.addMember),
                        onTap: () async {
                          final user = await showUserSearchSheet(
                            context: sheetContext,
                            chatService: widget.chatService,
                          );
                          if (user == null) return;
                          if (conversation.memberIds.contains(user.login)) {
                            return;
                          }
                          try {
                            await widget.chatService.addMember(
                              conversation.id,
                              user,
                            );
                            if (!mounted) return;
                            setState(() {
                              _conversation = widget.chatService
                                  .getConversation(conversation.id)!;
                            });
                            setSheetState(() {});
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text(strings.memberAdded)),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${strings.memberActionFailed}: $e',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  String get _leaveLabel {
    final strings = context.strings;
    if (_isDirect) return strings.deleteChat;
    if (_conversation.isAdmin) return strings.deleteGroupOrChannel;
    return _isChannel ? strings.leaveChannel : strings.leaveGroup;
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([widget.chatService, widget.blacklistService]),
      builder: (context, _) {
        final updated = widget.chatService.getConversation(_conversation.id);
        if (updated != null) _conversation = updated;

        return Scaffold(
          appBar: AppBar(title: Text(strings.profileInfo)),
          body: Column(
            children: [
              const SizedBox(height: 20),
              AvatarDisplay(
                name: _conversation.name,
                avatarPath: _conversation.avatarPath,
                avatarEmoji: conversationAvatarEmoji(_conversation),
                radius: 48,
                fontSize: 32,
              ),
              const SizedBox(height: 12),
              Text(_conversation.name,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              if (_isDirect && _conversation.contactStatus.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(_conversation.contactStatus,
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)),
              ],
              if (_isDirect && _conversation.contactBirthday != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${formatBirthday(_conversation.contactBirthday!)} (${strings.ageYears(calculateAge(_conversation.contactBirthday!))})',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
              ],
              if (_isGroup) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    '${strings.members}: ${_conversation.memberIds.join(', ')}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  ),
                ),
              ],
              if (_conversation.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
                  child: Text(_conversation.description,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)),
                ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: [
                  Tab(text: strings.images),
                  Tab(text: strings.videos),
                  Tab(text: strings.voices),
                  Tab(text: strings.files),
                  Tab(text: strings.music),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _MediaGrid(messages: widget.chatService.getMediaMessages(_conversation.id, MessageType.image)),
                    _MediaGrid(messages: widget.chatService.getMediaMessages(_conversation.id, MessageType.video)),
                    _MediaGrid(messages: widget.chatService.getMediaMessages(_conversation.id, MessageType.voice)),
                    _MediaGrid(messages: widget.chatService.getMediaMessages(_conversation.id, MessageType.file)),
                    _MediaGrid(messages: widget.chatService.getMediaMessages(_conversation.id, MessageType.music)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_isDirect)
                      _ActionButton(
                        icon: _isBlocked ? Icons.lock_open : Icons.block,
                        label: _isBlocked ? strings.unblockUser : strings.blockUser,
                        onPressed: _isBlocked ? _unblockUser : _blockUser,
                        isDestructive: !_isBlocked,
                      ),
                    if (_conversation.isAdmin && !_isDirect) ...[
                      _ActionButton(
                        icon: Icons.edit,
                        label: strings.rename,
                        onPressed: _rename,
                      ),
                      _ActionButton(
                        icon: Icons.people,
                        label: strings.manageMembers,
                        onPressed: _manageMembers,
                      ),
                    ],
                    if (_isGroup && !_conversation.isAdmin)
                      _ActionButton(
                        icon: Icons.people_outline,
                        label: strings.members,
                        onPressed: _manageMembers,
                      ),
                    _ActionButton(
                      icon: Icons.delete_outline,
                      label: _leaveLabel,
                      onPressed: _deleteOrLeave,
                      isDestructive: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MediaGrid extends StatelessWidget {
  const _MediaGrid({required this.messages});
  final List<Message> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Text(context.strings.noMedia,
            style: TextStyle(color: Colors.grey.shade600)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(6),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
      ),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final media = MediaPayload.tryParse(message.content);
        final isImage = message.type == MessageType.image ||
            message.type == MessageType.sticker ||
            message.type == MessageType.gif;

        return InkWell(
          onTap: media == null
              ? null
              : () => launchUrl(
                    Uri.parse(media.url),
                    mode: LaunchMode.externalApplication,
                  ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: media != null && isImage
                  ? Image.network(media.url, fit: BoxFit.cover)
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          media?.name ?? messageTypeLabel(message.type),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9),
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: color),
        label: Text(label, style: TextStyle(color: color)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          side: BorderSide(color: color.withOpacity(0.5)),
        ),
      ),
    );
  }
}
