import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../services/blacklist_service.dart';
import '../services/chat_service.dart';
import '../services/settings_service.dart';
import '../utils/helpers.dart';
import '../widgets/avatar_display.dart';
import '../widgets/confirm_dialogs.dart';
import 'stranger_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversation,
    required this.chatService,
    required this.blacklistService,
    required this.currentUserLogin,
    required this.settingsService,
  });

  final Conversation conversation;
  final ChatService chatService;
  final BlacklistService blacklistService;
  final String currentUserLogin;
  final SettingsService settingsService;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _messageFocusNode = FocusNode();
  final _messageKeys = <String, GlobalKey>{};

  late Conversation _conversation;
  bool _showScrollDown = false;
  bool _isTyping = false;
  final _viewedPosts = <String>{};

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _scrollController.addListener(_onScroll);
    widget.chatService.markMessagesRead(_conversation.id);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _messageFocusNode.requestFocus();
      _scrollToBottom(jump: true);
    });
  }

  @override
  void dispose() {
    if (_isTyping) {
      widget.chatService.setTyping(_conversation.id, false);
    }
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final atBottom = _scrollController.position.maxScrollExtent -
            _scrollController.offset <
        80;
    if (atBottom != !_showScrollDown) {
      setState(() => _showScrollDown = !atBottom);
    }
  }

  String _statusText(AppStrings strings) {
    if (_conversation.typingUsers.isNotEmpty) {
      if (_conversation.type == ConversationType.group) {
        final names = _conversation.typingUsers.join(', ');
        return strings.typingUsers(names);
      }
      return strings.typing;
    }

    return switch (_conversation.type) {
      ConversationType.direct =>
        _conversation.isOnline ? strings.online : strings.offline,
      ConversationType.group => strings.onlineCount(_conversation.onlineCount),
      ConversationType.channel =>
        strings.subscriberCount(_conversation.subscriberCount),
    };
  }

  void _onTextChanged(String text) {
    final shouldType = text.isNotEmpty;
    if (shouldType != _isTyping) {
      _isTyping = shouldType;
      widget.chatService.setTyping(_conversation.id, shouldType);
    }
  }

  Future<void> _sendText() async {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;

    if (!widget.chatService.canSendMessages(_conversation)) return;

    _messageController.clear();
    _onTextChanged('');

    await widget.chatService.sendMessage(
      conversationId: _conversation.id,
      type: MessageType.text,
      content: text,
    );
    _scrollToBottom();
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (jump) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      } else {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToMessage(String messageId) {
    final key = _messageKeys[messageId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        alignment: 0.3,
      );
    }
  }

  Future<void> _sendMedia(MessageType type) async {
    if (!widget.chatService.canSendMessages(_conversation)) return;
    final label = messageTypeLabel(type);
    await widget.chatService.sendMessage(
      conversationId: _conversation.id,
      type: type,
      content: label.isEmpty ? 'Содержимое' : label,
    );
    _scrollToBottom();
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => StrangerProfileScreen(
          conversation: _conversation,
          chatService: widget.chatService,
          blacklistService: widget.blacklistService,
          currentUserLogin: widget.currentUserLogin,
        ),
      ),
    );
  }

  Future<void> _showMessageActions(Message message) async {
    final strings = context.strings;
    final isOwn = message.senderId == widget.currentUserLogin;
    final isChannel = _conversation.type == ConversationType.channel;

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwn && !isChannel) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(strings.editMessage),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(strings.deleteForMe),
                onTap: () => Navigator.pop(context, 'delete_me'),
              ),
              ListTile(
                leading: Icon(Icons.delete_forever,
                    color: Theme.of(context).colorScheme.error),
                title: Text(strings.deleteForAll,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () => Navigator.pop(context, 'delete_all'),
              ),
            ],
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: Text(strings.pinForMe),
              onTap: () => Navigator.pop(context, 'pin_me'),
            ),
            if (isOwn || _conversation.isAdmin)
              ListTile(
                leading: const Icon(Icons.push_pin),
                title: Text(strings.pinForAll),
                onTap: () => Navigator.pop(context, 'pin_all'),
              ),
            ListTile(
              leading: const Icon(Icons.add_reaction_outlined),
              title: Text(strings.addReaction),
              onTap: () => Navigator.pop(context, 'react'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case 'edit':
        final newText = await showTextInputDialog(
          context: context,
          title: strings.editMessage,
          hint: strings.messageHint,
          initialValue: message.content,
          validator: (v) =>
              v == null || v.trim().isEmpty ? strings.nameRequired : null,
        );
        if (newText != null) {
          await widget.chatService.editMessage(
              _conversation.id, message.id, newText);
        }
      case 'delete_me':
        await widget.chatService.deleteMessage(
            _conversation.id, message.id, forEveryone: false);
      case 'delete_all':
        final confirmed = await showConfirmDialog(
          context: context,
          title: strings.deleteForAll,
          message: strings.deleteForAllConfirm,
          isDestructive: true,
        );
        if (confirmed == true) {
          await widget.chatService.deleteMessage(
              _conversation.id, message.id, forEveryone: true);
        }
      case 'pin_me':
        await widget.chatService.pinMessage(
            _conversation.id, message.id, forEveryone: false);
      case 'pin_all':
        await widget.chatService.pinMessage(
            _conversation.id, message.id, forEveryone: true);
      case 'react':
        await _showReactionPicker(message);
    }
  }

  Future<void> _showReactionPicker(Message message) async {
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🔥'];
    final emoji = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: emojis
                .map((e) => IconButton(
                      iconSize: 32,
                      onPressed: () => Navigator.pop(context, e),
                      icon: Text(e, style: const TextStyle(fontSize: 28)),
                    ))
                .toList(),
          ),
        ),
      ),
    );
    if (emoji != null) {
      await widget.chatService.toggleReaction(
          _conversation.id, message.id, emoji);
    }
  }

  Future<void> _showComments(Message post) async {
    final strings = context.strings;
    var visibleCount = 10;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return ListenableBuilder(
              listenable: widget.chatService,
              builder: (context, _) {
                final comments = widget.chatService.getComments(post.id);
                final shown = comments.take(visibleCount).toList();

                return DraggableScrollableSheet(
                  expand: false,
                  initialChildSize: 0.55,
                  minChildSize: 0.3,
                  maxChildSize: 0.9,
                  builder: (context, scrollController) {
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(strings.comments,
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            itemCount: shown.length +
                                (comments.length > visibleCount ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == shown.length) {
                                return TextButton(
                                  onPressed: () => setSheetState(
                                      () => visibleCount += 10),
                                  child: Text(strings.showMore),
                                );
                              }
                              final c = shown[index];
                              return ListTile(
                                leading: AvatarDisplay(
                                  name: c.senderName,
                                  avatarEmoji: c.senderEmoji,
                                  radius: 18,
                                ),
                                title: Text(c.senderName,
                                    style: const TextStyle(fontSize: 13)),
                                subtitle: Text(c.content),
                              );
                            },
                          ),
                        ),
                        if (widget.chatService.canSendMessages(_conversation))
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    decoration: InputDecoration(
                                      hintText: strings.commentHint,
                                    ),
                                    onSubmitted: (text) async {
                                      if (text.trim().isEmpty) return;
                                      await widget.chatService.addComment(
                                        postMessageId: post.id,
                                        conversationId: _conversation.id,
                                        content: text.trim(),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final canSend = widget.chatService.canSendMessages(_conversation);
    final isChannel = _conversation.type == ConversationType.channel;

    return ListenableBuilder(
      listenable: widget.chatService,
      builder: (context, _) {
        final updated = widget.chatService.getConversation(_conversation.id);
        if (updated != null) _conversation = updated;

        final messages = widget.chatService.getMessages(_conversation.id);
        final pinned = widget.chatService.getPinnedMessages(_conversation.id);

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: InkWell(
              onTap: _openProfile,
              child: Row(
                children: [
                  AvatarDisplay(
                    name: _conversation.name,
                    avatarPath: _conversation.avatarPath,
                    avatarEmoji: conversationAvatarEmoji(_conversation),
                    radius: 18,
                    fontSize: 14,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _conversation.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _statusText(strings),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  if (pinned.isNotEmpty)
                    _PinnedBar(
                      pinned: pinned,
                      onTap: (index) => _scrollToMessage(pinned[index].id),
                    ),
                  Expanded(
                    child: messages.isEmpty
                        ? Center(
                            child: Text(strings.noMessages,
                                style: TextStyle(color: Colors.grey.shade600)),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final prev = index > 0 ? messages[index - 1] : null;
                              final showDate = prev == null ||
                                  !_sameDay(prev.timestamp, message.timestamp);

                              _messageKeys.putIfAbsent(
                                  message.id, () => GlobalKey());

                              if (isChannel && _viewedPosts.add(message.id)) {
                                widget.chatService.incrementViews(
                                    _conversation.id, message.id);
                              }

                              return Column(
                                key: _messageKeys[message.id],
                                children: [
                                  if (showDate)
                                    _DateSeparator(
                                        date: message.timestamp),
                                  _MessageBubble(
                                    message: message,
                                    isOwn: message.senderId ==
                                        widget.currentUserLogin,
                                    showSender: _conversation.type !=
                                            ConversationType.direct ||
                                        message.senderId !=
                                            widget.currentUserLogin,
                                    isChannel: isChannel,
                                    commentCount: widget.chatService
                                        .getComments(message.id)
                                        .length,
                                    onLongPress: () =>
                                        _showMessageActions(message),
                                    onReactionTap: () =>
                                        _showReactionPicker(message),
                                    onCommentsTap: isChannel
                                        ? () => _showComments(message)
                                        : null,
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                  if (canSend)
                    _MessageInputBar(
                      controller: _messageController,
                      focusNode: _messageFocusNode,
                      onChanged: _onTextChanged,
                      onSend: _sendText,
                      onAttach: _showAttachMenu,
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Text(
                        strings.channelReadOnly,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                ],
              ),
              if (_showScrollDown)
                Positioned(
                  right: 16,
                  bottom: canSend ? 80 : 16,
                  child: FloatingActionButton.small(
                    onPressed: () => _scrollToBottom(),
                    child: const Icon(Icons.keyboard_arrow_down),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _showAttachMenu() async {
    final strings = context.strings;
    final type = await showModalBottomSheet<MessageType>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            _AttachTile(icon: Icons.mic, label: strings.voice, type: MessageType.voice),
            _AttachTile(icon: Icons.videocam, label: strings.video, type: MessageType.video),
            _AttachTile(icon: Icons.image, label: strings.image, type: MessageType.image),
            _AttachTile(icon: Icons.music_note, label: strings.music, type: MessageType.music),
            _AttachTile(icon: Icons.emoji_emotions, label: strings.sticker, type: MessageType.sticker),
            _AttachTile(icon: Icons.gif_box, label: strings.gif, type: MessageType.gif),
            _AttachTile(icon: Icons.attach_file, label: strings.file, type: MessageType.file),
          ],
        ),
      ),
    );
    if (type != null) await _sendMedia(type);
  }
}

class _PinnedBar extends StatelessWidget {
  const _PinnedBar({required this.pinned, required this.onTap});

  final List<Message> pinned;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: List.generate(pinned.length, (index) {
          final msg = pinned[index];
          final preview = msg.isDeletedForAll
              ? 'Сообщение удалено'
              : (msg.type == MessageType.text
                  ? msg.content
                  : messageTypeLabel(msg.type));
          return InkWell(
            onTap: () => onTap(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.push_pin, size: 16,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('${index + 1}. ',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            formatDateSeparator(date),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isOwn,
    required this.showSender,
    required this.isChannel,
    required this.commentCount,
    required this.onLongPress,
    required this.onReactionTap,
    this.onCommentsTap,
  });

  final Message message;
  final bool isOwn;
  final bool showSender;
  final bool isChannel;
  final int commentCount;
  final VoidCallback onLongPress;
  final VoidCallback onReactionTap;
  final VoidCallback? onCommentsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (message.isDeletedForAll) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Align(
          alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
          child: Text('Сообщение удалено',
              style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic, color: Colors.grey.shade600)),
        ),
      );
    }

    final content = message.type == MessageType.text
        ? message.content
        : messageTypeLabel(message.type);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (showSender && !isOwn) ...[
                AvatarDisplay(
                  name: message.senderName,
                  avatarEmoji: message.senderEmoji,
                  radius: 14,
                  fontSize: 12,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (showSender && !isOwn)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2, left: 4),
                          child: Text(message.senderName,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              )),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isOwn
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isOwn ? 16 : 4),
                            bottomRight: Radius.circular(isOwn ? 4 : 16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              content,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isOwn
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (message.isEdited)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Text('изм.',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: isOwn
                                              ? theme.colorScheme.onPrimary
                                                  .withOpacity(0.7)
                                              : Colors.grey.shade600,
                                          fontSize: 10,
                                        )),
                                  ),
                                Text(
                                  formatMessageTime(message.timestamp),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: isOwn
                                        ? theme.colorScheme.onPrimary
                                            .withOpacity(0.7)
                                        : Colors.grey.shade600,
                                    fontSize: 10,
                                  ),
                                ),
                                if (isOwn) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    message.isRead
                                        ? Icons.done_all
                                        : Icons.done,
                                    size: 14,
                                    color: message.isRead
                                        ? Colors.lightBlueAccent
                                        : theme.colorScheme.onPrimary
                                            .withOpacity(0.7),
                                  ),
                                ],
                                if (isChannel) ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.visibility,
                                      size: 12,
                                      color: isOwn
                                          ? theme.colorScheme.onPrimary
                                              .withOpacity(0.7)
                                          : Colors.grey.shade600),
                                  const SizedBox(width: 2),
                                  Text('${message.viewCount}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        fontSize: 10,
                                        color: isOwn
                                            ? theme.colorScheme.onPrimary
                                                .withOpacity(0.7)
                                            : Colors.grey.shade600,
                                      )),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (message.reactions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: GestureDetector(
                            onTap: onReactionTap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                message.reactions.values.toSet().join(' '),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                      if (isChannel && onCommentsTap != null)
                        InkWell(
                          onTap: onCommentsTap,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4, left: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline,
                                    size: 14, color: theme.colorScheme.primary),
                                const SizedBox(width: 4),
                                Text('$commentCount',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.primary)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageInputBar extends StatelessWidget {
  const _MessageInputBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: onAttach,
              ),
              Expanded(
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.enter) {
                      final isShift = HardwareKeyboard.instance.isShiftPressed;
                      if (!isShift) {
                        onSend();
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    maxLines: 6,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: context.strings.messageHint,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: onSend,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachTile extends StatelessWidget {
  const _AttachTile({
    required this.icon,
    required this.label,
    required this.type,
  });

  final IconData icon;
  final String label;
  final MessageType type;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pop(context, type),
      child: SizedBox(
        width: MediaQuery.of(context).size.width / 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
