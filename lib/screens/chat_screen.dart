import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../models/conversation.dart';
import '../models/media_payload.dart';
import '../models/message.dart';
import '../services/blacklist_service.dart';
import '../services/chat_service.dart';
import '../services/presence_service.dart';
import '../services/settings_service.dart';
import '../utils/helpers.dart';
import '../utils/main_tab_bus.dart';
import '../services/voice_recorder.dart';
import '../widgets/avatar_display.dart';
import '../widgets/circle_video_player.dart';
import '../widgets/murkot_decor.dart';
import '../widgets/confirm_dialogs.dart';
import '../widgets/voice_message_player.dart';
import 'forward_message_sheet.dart';
import 'stranger_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversation,
    required this.chatService,
    required this.blacklistService,
    required this.presenceService,
    required this.currentUserLogin,
    required this.settingsService,
    this.initialMessageId,
  });

  final Conversation conversation;
  final ChatService chatService;
  final BlacklistService blacklistService;
  final PresenceService presenceService;
  final String currentUserLogin;
  final SettingsService settingsService;

  /// If set, the chat opens scrolled to this message (search result).
  final String? initialMessageId;

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
  bool _loadingHistory = false;
  Message? _replyTo;
  bool _searchMode = false;
  final _chatSearchController = TextEditingController();
  String _chatSearchQuery = '';
  List<Message>? _remoteSearchResults;
  bool _searchLoading = false;
  final _viewedPosts = <String>{};
  bool _recordingVoice = false;
  DateTime? _voiceStartedAt;
  Timer? _voiceTick;

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _scrollController.addListener(_onScroll);
    widget.chatService.setActiveConversation(_conversation.id);
    _bootstrapMessages();
  }

  Future<void> _bootstrapMessages() async {
    await widget.chatService.ensureMessagesLoaded(_conversation.id);
    if (!mounted) return;
    await widget.chatService.markMessagesRead(_conversation.id);

    final targetId = widget.initialMessageId;
    if (targetId != null) {
      await _revealMessage(targetId);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _messageFocusNode.requestFocus();
      _scrollToBottom(jump: true);
    });
  }

  /// Loads older pages until [messageId] is present, then scrolls to it.
  Future<void> _revealMessage(String messageId) async {
    bool isLoaded() => widget.chatService
        .getMessages(_conversation.id)
        .any((m) => m.id == messageId);

    var guard = 0;
    while (!isLoaded() &&
        widget.chatService.hasMoreMessages(_conversation.id) &&
        guard < 12) {
      await widget.chatService.loadOlderMessages(_conversation.id);
      guard++;
    }
    if (!mounted) return;

    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (isLoaded()) {
        _scrollToMessage(messageId);
      } else {
        _scrollToBottom(jump: true);
      }
    });
  }

  @override
  void dispose() {
    _voiceTick?.cancel();
    if (_recordingVoice) {
      cancelVoiceRecording();
    }
    if (_isTyping) {
      widget.chatService.setTyping(_conversation.id, false);
    }
    widget.chatService.setActiveConversation(null);
    _messageController.dispose();
    _chatSearchController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final atBottom = position.maxScrollExtent - position.pixels < 80;
    if (atBottom != !_showScrollDown) {
      setState(() => _showScrollDown = !atBottom);
    }

    if (position.pixels <= 48) {
      _loadOlder();
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingHistory || _searchMode) return;
    if (!widget.chatService.hasMoreMessages(_conversation.id)) return;
    if (widget.chatService.isLoadingMessages(_conversation.id)) return;

    setState(() => _loadingHistory = true);
    final beforeMax = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final beforeOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;

    await widget.chatService.loadOlderMessages(_conversation.id);
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final afterMax = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(beforeOffset + (afterMax - beforeMax));
    });
    setState(() => _loadingHistory = false);
  }

  Future<void> _onChatSearchChanged(String value) async {
    setState(() {
      _chatSearchQuery = value;
      _searchLoading = value.trim().length >= 2;
    });
    if (value.trim().length < 2) {
      setState(() {
        _remoteSearchResults = null;
        _searchLoading = false;
      });
      return;
    }

    final results = await widget.chatService.searchMessagesRemote(
      _conversation.id,
      value,
    );
    if (!mounted || _chatSearchController.text != value) return;
    setState(() {
      _remoteSearchResults = results;
      _searchLoading = false;
    });
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
      ConversationType.direct => widget.presenceService.isOnline(_conversation.name)
          ? strings.online
          : formatLastSeen(
              widget.presenceService.lastSeenOf(_conversation.name) ??
                  _conversation.contactLastSeen,
              isRu: strings.isRu,
            ),
      ConversationType.group => strings.onlineCount(
          _conversation.memberIds
              .where(widget.presenceService.isOnline)
              .length,
        ),
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

    final replyId = _replyTo?.id;
    _messageController.clear();
    _onTextChanged('');
    setState(() => _replyTo = null);

    try {
      await widget.chatService.sendMessage(
        conversationId: _conversation.id,
        type: MessageType.text,
        content: text,
        replyToId: replyId,
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      // Offline queue keeps the bubble; only hard policy errors show snackbar.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
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

  Future<void> _sendMedia(MessageType type, {bool asCircle = false}) async {
    if (!widget.chatService.canSendMessages(_conversation)) return;

    final strings = context.strings;
    final picked = await _pickMedia(type, asCircle: asCircle);
    if (picked == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.mediaUploading)),
    );

    try {
      await widget.chatService.sendMediaBytes(
        conversationId: _conversation.id,
        type: type,
        bytes: picked.bytes,
        fileName: picked.name,
        contentType: picked.contentType,
        durationMs: picked.durationMs,
        isCircle: asCircle || picked.isCircle,
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${strings.mediaUploadFailed}: $e')),
      );
    }
  }

  Future<void> _startVoiceNote() async {
    if (!widget.chatService.canSendMessages(_conversation) || _recordingVoice) {
      return;
    }
    final ok = await startVoiceRecording();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет доступа к микрофону')),
      );
      return;
    }
    setState(() {
      _recordingVoice = true;
      _voiceStartedAt = DateTime.now();
    });
    _voiceTick?.cancel();
    _voiceTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _stopVoiceNote({required bool send}) async {
    if (!_recordingVoice) return;
    _voiceTick?.cancel();
    _voiceTick = null;
    setState(() => _recordingVoice = false);
    if (!send) {
      await cancelVoiceRecording();
      _voiceStartedAt = null;
      return;
    }

    final recording = await stopVoiceRecording();
    _voiceStartedAt = null;
    if (recording == null || recording.bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось записать голосовое')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings.mediaUploading)),
    );
    try {
      await widget.chatService.sendMediaBytes(
        conversationId: _conversation.id,
        type: MessageType.voice,
        bytes: recording.bytes,
        fileName: recording.fileName,
        contentType: recording.mimeType,
        durationMs: recording.durationMs,
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strings.mediaUploadFailed}: $e')),
      );
    }
  }

  Future<void> _sendCircleVideo() async {
    await _sendMedia(MessageType.video, asCircle: true);
  }

  Future<_PickedMedia?> _pickMedia(
    MessageType type, {
    bool asCircle = false,
  }) async {
    switch (type) {
      case MessageType.image:
      case MessageType.sticker:
      case MessageType.gif:
        final file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        if (file == null) return null;
        return _PickedMedia(
          bytes: await file.readAsBytes(),
          name: file.name,
          contentType: 'image/jpeg',
        );
      case MessageType.video:
        final file = await ImagePicker().pickVideo(
          source: asCircle ? ImageSource.camera : ImageSource.gallery,
          maxDuration: asCircle ? const Duration(seconds: 60) : null,
        );
        if (file == null) return null;
        return _PickedMedia(
          bytes: await file.readAsBytes(),
          name: file.name,
          contentType: 'video/mp4',
          isCircle: asCircle,
        );
      case MessageType.voice:
      case MessageType.music:
        final result = await FilePicker.platform.pickFiles(
          type: FileType.audio,
          withData: true,
        );
        final file = result?.files.single;
        if (file?.bytes == null) return null;
        return _PickedMedia(
          bytes: file!.bytes!,
          name: file.name,
          contentType: 'audio/mpeg',
        );
      case MessageType.file:
        final result = await FilePicker.platform.pickFiles(withData: true);
        final file = result?.files.single;
        if (file?.bytes == null) return null;
        return _PickedMedia(
          bytes: file!.bytes!,
          name: file.name,
          contentType: 'application/octet-stream',
        );
      case MessageType.text:
      case MessageType.emoji:
        return null;
    }
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
            if (!isChannel)
              ListTile(
                leading: const Icon(Icons.reply),
                title: Text(strings.reply),
                onTap: () => Navigator.pop(context, 'reply'),
              ),
            ListTile(
              leading: const Icon(Icons.forward),
              title: Text(strings.forward),
              onTap: () => Navigator.pop(context, 'forward'),
            ),
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
      case 'reply':
        setState(() => _replyTo = message);
        _messageFocusNode.requestFocus();
      case 'forward':
        await showForwardMessageSheet(
          context: context,
          chatService: widget.chatService,
          message: message,
        );
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
      listenable: Listenable.merge([
        widget.chatService,
        widget.blacklistService,
        widget.presenceService,
      ]),
      builder: (context, _) {
        final updated = widget.chatService.getConversation(_conversation.id);
        if (updated != null) _conversation = updated;

        // Wide (desktop) layout: nav rail 25% | chat 50% | attachments 25%;
        // all bubbles are left-aligned in the same format as peer messages.
        final isWide = MediaQuery.of(context).size.width >= 720;

        final messages = _searchMode && _chatSearchQuery.isNotEmpty
            ? (_remoteSearchResults ??
                widget.chatService.searchMessages(
                  _conversation.id,
                  _chatSearchQuery,
                ))
            : widget.chatService.getMessages(_conversation.id);
        final pinned = widget.chatService.getPinnedMessages(_conversation.id);
        final isBlocked =
            widget.chatService.isDirectBlocked(_conversation);
        final isOnlineDirect = _conversation.type == ConversationType.direct &&
            widget.presenceService.isOnline(_conversation.name);

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: _searchMode
                ? TextField(
                    controller: _chatSearchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: strings.searchInChatHint,
                      border: InputBorder.none,
                    ),
                    onChanged: _onChatSearchChanged,
                  )
                : InkWell(
                    onTap: _openProfile,
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            AvatarDisplay(
                              name: _conversation.name,
                              avatarPath: _conversation.avatarPath,
                              avatarEmoji:
                                  conversationAvatarEmoji(_conversation),
                              radius: 18,
                              fontSize: 14,
                            ),
                            if (isOnlineDirect)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.colorScheme.surface,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
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
                                  color: isOnlineDirect
                                      ? Colors.green.shade700
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            actions: [
              IconButton(
                tooltip: strings.searchInChat,
                icon: Icon(_searchMode ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    _searchMode = !_searchMode;
                    if (!_searchMode) {
                      _chatSearchController.clear();
                      _chatSearchQuery = '';
                      _remoteSearchResults = null;
                    }
                  });
                },
              ),
            ],
          ),
          body: _DesktopChatLayout(
            isWide: isWide,
            navRail: isWide ? _buildDesktopNavRail(context) : null,
            sidePanel: isWide
                ? _buildDesktopSidePanel(
                    context,
                    canSend: canSend && !isBlocked,
                  )
                : null,
            child: Stack(
            children: [
              Column(
                children: [
                  if (pinned.isNotEmpty)
                    _PinnedBar(
                      pinned: pinned,
                      onTap: (index) => _scrollToMessage(pinned[index].id),
                    ),
                  if (_loadingHistory ||
                      _searchLoading ||
                      widget.chatService.isLoadingMessages(_conversation.id))
                    const LinearProgressIndicator(minHeight: 2),
                  Expanded(
                    child: messages.isEmpty
                        ? Center(
                            child: widget.chatService
                                    .isLoadingMessages(_conversation.id)
                                ? const CircularProgressIndicator()
                                : Text(
                                    _searchMode && _chatSearchQuery.isNotEmpty
                                        ? strings.noSearchResults
                                        : strings.noMessages,
                                    style:
                                        TextStyle(color: Colors.grey.shade600),
                                  ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            itemCount: messages.length +
                                (widget.chatService
                                        .hasMoreMessages(_conversation.id) &&
                                    !_searchMode
                                    ? 1
                                    : 0),
                            itemBuilder: (context, index) {
                              if (!_searchMode &&
                                  widget.chatService
                                      .hasMoreMessages(_conversation.id) &&
                                  index == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Center(
                                    child: TextButton(
                                      onPressed: _loadOlder,
                                      child: Text(strings.loadOlderMessages),
                                    ),
                                  ),
                                );
                              }

                              final messageIndex = !_searchMode &&
                                      widget.chatService.hasMoreMessages(
                                          _conversation.id)
                                  ? index - 1
                                  : index;
                              final message = messages[messageIndex];
                              final prev = messageIndex > 0
                                  ? messages[messageIndex - 1]
                                  : null;
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
                                    _DateSeparator(date: message.timestamp),
                                  _MessageBubble(
                                    message: message,
                                    isOwn: message.senderId ==
                                        widget.currentUserLogin,
                                    forceLeft: isWide,
                                    senderAvatarUrl: widget.chatService
                                        .avatarUrlForLogin(message.senderId),
                                    showSender: isWide ||
                                        _conversation.type !=
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
                                    onRetry: message.sendStatus ==
                                            MessageSendStatus.failed
                                        ? () => widget.chatService
                                            .retryFailedMessage(message.id)
                                        : null,
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                  if (isBlocked)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: theme.colorScheme.errorContainer,
                      child: Text(
                        strings.userBlockedBanner,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    )
                  else if (canSend) ...[
                    if (_replyTo != null)
                      Material(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.reply,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(
                            '${strings.replyTo} ${_replyTo!.senderName}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            messagePreviewText(_replyTo!, maxChars: 48),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _replyTo = null),
                          ),
                        ),
                      ),
                    if (_recordingVoice)
                      Material(
                        color: theme.colorScheme.errorContainer,
                        child: ListTile(
                          leading: Icon(
                            Icons.mic,
                            color: theme.colorScheme.error,
                          ),
                          title: Text(
                            'Запись… ${_voiceElapsed()}',
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Отмена',
                                onPressed: () => _stopVoiceNote(send: false),
                                icon: const Icon(Icons.close),
                              ),
                              IconButton(
                                tooltip: 'Отправить',
                                onPressed: () => _stopVoiceNote(send: true),
                                icon: Icon(
                                  Icons.send,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      _MessageInputBar(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        onChanged: _onTextChanged,
                        onSend: _sendText,
                        // Desktop: attachments live in the right-side panel.
                        onAttach: isWide ? null : _showAttachMenu,
                        onVoiceStart: _startVoiceNote,
                      ),
                  ] else
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
                  bottom: canSend && !isBlocked ? 80 : 16,
                  child: FloatingActionButton.small(
                    onPressed: () => _scrollToBottom(),
                    child: const Icon(Icons.keyboard_arrow_down),
                  ),
                ),
            ],
            ),
          ),
        );
      },
    );
  }

  /// Desktop-only vertical navigation (chats / groups / channels / profile).
  Widget _buildDesktopNavRail(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final selected = switch (_conversation.type) {
      ConversationType.direct => 0,
      ConversationType.group => 1,
      ConversationType.channel => 2,
    };

    void go(int index) {
      mainTabIndex.value = index;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RailItem(
            icon: Icons.chat_bubble_outline,
            selectedIcon: Icons.chat_bubble,
            label: strings.chats,
            isSelected: selected == 0,
            onTap: () => go(0),
          ),
          _RailItem(
            icon: Icons.group_outlined,
            selectedIcon: Icons.group,
            label: strings.groups,
            isSelected: selected == 1,
            onTap: () => go(1),
          ),
          _RailItem(
            icon: Icons.campaign_outlined,
            selectedIcon: Icons.campaign,
            label: strings.channels,
            isSelected: selected == 2,
            onTap: () => go(2),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          _RailItem(
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            label: strings.profile,
            isSelected: false,
            onTap: () => go(3),
          ),
          const Spacer(),
          const Center(child: CitrusSlice(size: 44, opacity: 0.25)),
        ],
      ),
    );
  }

  /// Desktop-only attachments panel (replaces the popup attach menu).
  Widget _buildDesktopSidePanel(BuildContext context, {required bool canSend}) {
    final strings = context.strings;
    final theme = Theme.of(context);

    if (!canSend) {
      return ColoredBox(
        color: theme.colorScheme.surface,
        child: const Center(
          child: StretchCatSilhouette(width: 150, opacity: 0.12),
        ),
      );
    }

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.attachmentsPanel,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.7,
              children: [
                _SidePanelTile(
                  icon: Icons.image,
                  label: strings.image,
                  onTap: () => _sendMedia(MessageType.image),
                ),
                _SidePanelTile(
                  icon: Icons.videocam,
                  label: strings.video,
                  onTap: () => _sendMedia(MessageType.video),
                ),
                _SidePanelTile(
                  icon: Icons.motion_photos_on_outlined,
                  label: 'Кружок',
                  onTap: _sendCircleVideo,
                ),
                _SidePanelTile(
                  icon: Icons.music_note,
                  label: strings.music,
                  onTap: () => _sendMedia(MessageType.music),
                ),
                _SidePanelTile(
                  icon: Icons.gif_box,
                  label: strings.gif,
                  onTap: () => _sendMedia(MessageType.gif),
                ),
                _SidePanelTile(
                  icon: Icons.attach_file,
                  label: strings.file,
                  onTap: () => _sendMedia(MessageType.file),
                ),
                _SidePanelTile(
                  icon: Icons.emoji_emotions,
                  label: strings.sticker,
                  onTap: () => _sendMedia(MessageType.sticker),
                ),
                _SidePanelTile(
                  icon: Icons.mic,
                  label: strings.voice,
                  onTap: _startVoiceNote,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _voiceElapsed() {
    final started = _voiceStartedAt;
    if (started == null) return '0:00';
    final sec = DateTime.now().difference(started).inSeconds;
    final m = sec ~/ 60;
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _showAttachMenu() async {
    final strings = context.strings;
    final type = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            _AttachTile(icon: Icons.mic, label: strings.voice, type: MessageType.voice),
            _AttachActionTile(
              icon: Icons.motion_photos_on_outlined,
              label: 'Кружок',
              onTap: () => Navigator.pop(context, 'circle'),
            ),
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
    if (type == 'circle') {
      await _sendCircleVideo();
    } else if (type is MessageType) {
      await _sendMedia(type);
    }
  }
}

/// Wide screens: nav rail (25%) | chat (50%) | attachments panel (25%).
/// Narrow screens: the chat fills everything.
class _DesktopChatLayout extends StatelessWidget {
  const _DesktopChatLayout({
    required this.isWide,
    required this.child,
    this.navRail,
    this.sidePanel,
  });

  final bool isWide;
  final Widget child;
  final Widget? navRail;
  final Widget? sidePanel;

  @override
  Widget build(BuildContext context) {
    if (!isWide) return child;

    final theme = Theme.of(context);
    final dividerColor = theme.dividerColor.withValues(alpha: 0.4);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 1, child: navRail ?? const SizedBox.shrink()),
        Container(width: 1, color: dividerColor),
        Expanded(flex: 2, child: child),
        Container(width: 1, color: dividerColor),
        Expanded(flex: 1, child: sidePanel ?? const SizedBox.shrink()),
      ],
    );
  }
}

/// Vertical navigation item for the desktop rail.
class _RailItem extends StatelessWidget {
  const _RailItem({
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
    final color =
        isSelected ? theme.colorScheme.primary : Colors.grey.shade700;

    return Material(
      color: isSelected
          ? theme.colorScheme.primary.withValues(alpha: 0.10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(isSelected ? selectedIcon : icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Attachment shortcut tile in the desktop side panel.
class _SidePanelTile extends StatelessWidget {
  const _SidePanelTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          final media = MediaPayload.tryParse(msg.content);
          final preview = msg.isDeletedForAll
              ? 'Сообщение удалено'
              : (msg.type == MessageType.text
                  ? msg.content
                  : (media?.name ?? messageTypeLabel(msg.type)));
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
    this.onRetry,
    this.forceLeft = false,
    this.senderAvatarUrl,
  });

  final Message message;
  final bool isOwn;
  final bool showSender;
  final bool isChannel;
  final int commentCount;
  final VoidCallback onLongPress;
  final VoidCallback onReactionTap;
  final VoidCallback? onCommentsTap;
  final VoidCallback? onRetry;

  /// Desktop mode: align every bubble to the left regardless of sender.
  final bool forceLeft;
  final String? senderAvatarUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignRight = isOwn && !forceLeft;
    // Desktop: own messages use the same format as the peer's, with avatar
    // and sender name on the left.
    final showAvatar = showSender && (!isOwn || forceLeft);

    if (message.isDeletedForAll) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Align(
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: Text('Сообщение удалено',
              style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic, color: Colors.grey.shade600)),
        ),
      );
    }

    final media = MediaPayload.tryParse(message.content);
    final isImageType = message.type == MessageType.image ||
        message.type == MessageType.sticker ||
        message.type == MessageType.gif;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (showAvatar) ...[
                AvatarDisplay(
                  name: message.senderName,
                  avatarPath: senderAvatarUrl,
                  avatarEmoji: message.senderEmoji,
                  radius: 14,
                  fontSize: 12,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: math.min(
                      MediaQuery.of(context).size.width * 0.72,
                      440,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: alignRight
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (showAvatar)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2, left: 4),
                          child: Text(message.senderName,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              )),
                        ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: media != null && isImageType ? 6 : 14,
                          vertical: media != null && isImageType ? 6 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: isOwn
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(alignRight ? 16 : 4),
                            bottomRight: Radius.circular(alignRight ? 4 : 16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (message.replyToId != null) ...[
                              Container(
                                constraints:
                                    const BoxConstraints(maxWidth: 280),
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: (isOwn
                                          ? theme.colorScheme.onPrimary
                                          : theme.colorScheme.primary)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border(
                                    left: BorderSide(
                                      color: isOwn
                                          ? theme.colorScheme.onPrimary
                                          : theme.colorScheme.primary,
                                      width: 3,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message.replyToSender ?? '',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: isOwn
                                            ? theme.colorScheme.onPrimary
                                            : theme.colorScheme.primary,
                                      ),
                                    ),
                                    Text(
                                      truncateChatPreview(
                                        message.replyToContent,
                                        maxChars: 48,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                        color: isOwn
                                            ? theme.colorScheme.onPrimary
                                                .withValues(alpha: 0.9)
                                            : theme.colorScheme.onSurface
                                                .withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (media != null &&
                                message.type == MessageType.voice)
                              VoiceMessagePlayer(
                                url: media.url,
                                durationMs: media.durationMs,
                                foreground: isOwn
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurface,
                              )
                            else if (media != null &&
                                message.type == MessageType.video &&
                                media.isCircle)
                              CircleVideoPlayer(url: media.url)
                            else if (media != null && isImageType)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  media.url,
                                  width: 220,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Text(
                                    media.name,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: isOwn
                                          ? theme.colorScheme.onPrimary
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              )
                            else if (media != null)
                              InkWell(
                                onTap: () => launchUrl(
                                  Uri.parse(media.url),
                                  mode: LaunchMode.externalApplication,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      message.type == MessageType.video
                                          ? Icons.videocam_outlined
                                          : Icons.insert_drive_file_outlined,
                                      size: 20,
                                      color: isOwn
                                          ? theme.colorScheme.onPrimary
                                          : theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        media.name,
                                        style:
                                            theme.textTheme.bodyMedium?.copyWith(
                                          color: isOwn
                                              ? theme.colorScheme.onPrimary
                                              : theme.colorScheme.onSurface,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Text(
                                message.type == MessageType.text
                                    ? message.content
                                    : messageTypeLabel(message.type),
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
                                  if (message.sendStatus ==
                                      MessageSendStatus.sending)
                                    Icon(
                                      Icons.schedule,
                                      size: 14,
                                      color: theme.colorScheme.onPrimary
                                          .withOpacity(0.7),
                                    )
                                  else if (message.sendStatus ==
                                      MessageSendStatus.failed)
                                    GestureDetector(
                                      onTap: onRetry,
                                      child: Icon(
                                        Icons.error_outline,
                                        size: 14,
                                        color: Colors.orange.shade200,
                                      ),
                                    )
                                  else
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
    required this.onVoiceStart,
    this.onAttach,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback? onAttach;
  final VoidCallback onVoiceStart;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final hasText = value.text.trim().isNotEmpty;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (onAttach != null)
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: onAttach,
                    ),
                  Expanded(
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.enter) {
                          final isShift =
                              HardwareKeyboard.instance.isShiftPressed;
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
                  if (hasText)
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: onSend,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  else
                    IconButton(
                      tooltip: 'Голосовое',
                      icon: const Icon(Icons.mic),
                      onPressed: onVoiceStart,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                ],
              );
            },
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
    return _AttachActionTile(
      icon: icon,
      label: label,
      onTap: () => Navigator.pop(context, type),
    );
  }
}

class _AttachActionTile extends StatelessWidget {
  const _AttachActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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

class _PickedMedia {
  const _PickedMedia({
    required this.bytes,
    required this.name,
    required this.contentType,
    this.durationMs,
    this.isCircle = false,
  });

  final Uint8List bytes;
  final String name;
  final String contentType;
  final int? durationMs;
  final bool isCircle;
}
