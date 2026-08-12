import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../models/conversation.dart';
import '../models/media_payload.dart';
import '../models/message.dart';
import '../models/system_payload.dart';
import '../models/user.dart';
import '../services/blacklist_service.dart';
import '../services/chat_service.dart';
import '../services/settings_service.dart';
import '../utils/helpers.dart';
import '../widgets/avatar_display.dart' hide pickRandomEmoji;
import '../widgets/confirm_dialogs.dart';
import '../widgets/dev_card.dart';
import '../widgets/murkot_decor.dart';
import '../widgets/unlumen/murkot_fx.dart';
import 'media_viewer_screen.dart';
import 'user_search_sheet.dart';

class StrangerProfileScreen extends StatefulWidget {
  const StrangerProfileScreen({
    super.key,
    required this.conversation,
    required this.chatService,
    required this.blacklistService,
    required this.currentUserLogin,
    this.settingsService,
  });

  final Conversation conversation;
  final ChatService chatService;
  final BlacklistService blacklistService;
  final String currentUserLogin;
  final SettingsService? settingsService;

  @override
  State<StrangerProfileScreen> createState() => _StrangerProfileScreenState();
}

class _StrangerProfileScreenState extends State<StrangerProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Conversation _conversation;
  User? _peerProfile;

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _tabController = TabController(length: 5, vsync: this);
    if (_conversation.type == ConversationType.direct) {
      _loadPeerProfile();
    }
  }

  Future<void> _loadPeerProfile() async {
    final profile =
        await widget.chatService.fetchProfileByLogin(_conversation.name);
    if (mounted && profile != null) {
      setState(() => _peerProfile = profile);
    }
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
    final peer = _conversation.name;
    final confirmed = await showConfirmDialog(
      context: context,
      title: strings.blockUser,
      message: strings.blockUserConfirm(peer),
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.blacklistService.blockUser(peer);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.blockUser)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.blockFailed(e))),
      );
    }
  }

  Future<void> _unblockUser() async {
    try {
      await widget.blacklistService.unblockUser(_conversation.name);
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.unblockFailed(e))),
      );
    }
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

  Future<void> _changeAvatar() async {
    final strings = context.strings;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    try {
      final bytes = await file.readAsBytes();
      await widget.chatService.updateConversationAvatarBytes(
        _conversation.id,
        bytes,
      );
      if (!mounted) return;
      setState(() {
        _conversation = widget.chatService.getConversation(_conversation.id) ??
            _conversation;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${strings.changeAvatar}: $e')),
      );
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
      await widget.chatService.sendSystemMessage(
        _conversation.id,
        SystemPayload(
          text:
              '${widget.currentUserLogin} изменил(а) название на «${name.trim()}»',
          actorLogin: widget.currentUserLogin,
        ).encode(),
      );
      if (mounted) {
        setState(() {
          _conversation = widget.chatService.getConversation(_conversation.id)!;
        });
      }
    }
  }

  Future<void> _editDescription() async {
    final strings = context.strings;
    final text = await showTextInputDialog(
      context: context,
      title: strings.editDescription,
      hint: strings.descriptionHint,
      initialValue: _conversation.description,
      maxLines: 4,
      maxLength: 280,
    );
    if (text == null) return;

    final trimmed = text.trim();
    await widget.chatService.updateConversation(
      _conversation.copyWith(description: trimmed),
    );
    await widget.chatService.sendSystemMessage(
      _conversation.id,
      SystemPayload(
        text: trimmed.isEmpty
            ? '${widget.currentUserLogin} убрал(а) описание'
            : '${widget.currentUserLogin} обновил(а) описание',
        actorLogin: widget.currentUserLogin,
      ).encode(),
    );
    if (!mounted) return;
    setState(() {
      _conversation =
          widget.chatService.getConversation(_conversation.id) ?? _conversation;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.descriptionUpdated)),
    );
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
                        onTap: () async {
                          if (member == widget.currentUserLogin) return;
                          try {
                            final users =
                                await widget.chatService.searchUsers(member);
                            final exact = users.where(
                              (u) =>
                                  u.login.toLowerCase() ==
                                  member.toLowerCase(),
                            );
                            if (exact.isEmpty || !mounted) return;
                            final dm = await widget.chatService
                                .openDirectChat(exact.first);
                            if (!mounted) return;
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) => StrangerProfileScreen(
                                  conversation: dm,
                                  chatService: widget.chatService,
                                  blacklistService: widget.blacklistService,
                                  currentUserLogin: widget.currentUserLogin,
                                ),
                              ),
                            );
                          } catch (_) {}
                        },
                        leading: AvatarDisplay(
                          name: member,
                          avatarPath:
                              widget.chatService.avatarUrlForLogin(member),
                          avatarEmoji:
                              widget.chatService.emojiForLogin(member) ??
                                  pickRandomEmoji(member.hashCode),
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
          appBar: AppBar(
            leading: const MurkotBackButton(),
            title: Text(strings.profileInfo),
            actions: [
              if (widget.settingsService != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: MurkotThemeSwitch(
                      settings: widget.settingsService!,
                    ),
                  ),
                ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 720;
              final header = _buildProfileHeader(context, theme, strings);
              final media = _buildMediaSection(strings);
              final actions = _ProfileActionsSheet(
                actions: [
                  if (_isDirect)
                    _ProfileAction(
                      icon: _isBlocked ? Icons.lock_open : Icons.block,
                      label: _isBlocked
                          ? strings.unblockUser
                          : strings.blockUser,
                      onPressed: _isBlocked ? _unblockUser : _blockUser,
                      isDestructive: !_isBlocked,
                    ),
                  if (_conversation.isAdmin && !_isDirect) ...[
                    _ProfileAction(
                      icon: Icons.photo_camera_outlined,
                      label: strings.changeAvatar,
                      onPressed: _changeAvatar,
                    ),
                    _ProfileAction(
                      icon: Icons.edit,
                      label: strings.rename,
                      onPressed: _rename,
                    ),
                    _ProfileAction(
                      icon: Icons.notes_outlined,
                      label: strings.editDescription,
                      onPressed: _editDescription,
                    ),
                    _ProfileAction(
                      icon: Icons.people,
                      label: strings.manageMembers,
                      onPressed: _manageMembers,
                    ),
                  ],
                  if (_isGroup && !_conversation.isAdmin)
                    _ProfileAction(
                      icon: Icons.people_outline,
                      label: strings.members,
                      onPressed: _manageMembers,
                    ),
                  _ProfileAction(
                    icon: Icons.delete_outline,
                    label: _leaveLabel,
                    onPressed: _deleteOrLeave,
                    isDestructive: true,
                  ),
                ],
              );

              if (isDesktop) {
                return Column(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                              child: header,
                            ),
                          ),
                          VerticalDivider(
                            width: 1,
                            color: theme.dividerColor.withValues(alpha: 0.4),
                          ),
                          Expanded(child: media),
                        ],
                      ),
                    ),
                    actions,
                  ],
                );
              }

              return Column(
                children: [
                  const SizedBox(height: 20),
                  header,
                  const SizedBox(height: 12),
                  Expanded(child: media),
                  actions,
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    ThemeData theme,
    AppStrings strings,
  ) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 720;
    final radius = isDesktop
        ? (MediaQuery.sizeOf(context).width * 0.25) / 2
        : 48.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _conversation.avatarPath == null
              ? null
              : () => MediaViewerScreen.open(
                    context,
                    urls: [_conversation.avatarPath!],
                    title: _conversation.name,
                  ),
          child: AvatarDisplay(
            name: _conversation.name,
            avatarPath: _conversation.avatarPath,
            avatarEmoji: conversationAvatarEmoji(_conversation),
            radius: radius,
            fontSize: isDesktop ? radius * 0.55 : 32,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _conversation.name,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: isDesktop ? 28 : null,
          ),
        ),
        if (_isDirect && _conversation.contactStatus.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.push_pin_outlined,
                          size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        strings.pinnedNoteLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _conversation.contactStatus,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_isDirect && _conversation.contactBirthday != null) ...[
          const SizedBox(height: 6),
          Text(
            '${formatBirthday(_conversation.contactBirthday!)} (${strings.ageYears(calculateAge(_conversation.contactBirthday!))})',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
        if (_isDirect &&
            _peerProfile != null &&
            DevCardView.hasContent(_peerProfile!)) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.dividerColor),
              ),
              child: DevCardView(
                user: _peerProfile!,
                showPlaceholderWhenEmpty: false,
              ),
            ),
          ),
        ],
        if (_isGroup) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '${strings.members}: ${_conversation.memberIds.join(', ')}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
        if (!_isDirect)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            child: Text(
              _conversation.description.isNotEmpty
                  ? _conversation.description
                  : strings.noDescription,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
                fontStyle: _conversation.description.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMediaSection(AppStrings strings) {
    return Column(
      children: [
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
              _MediaGrid(
                messages: widget.chatService
                    .getMediaMessages(_conversation.id, MessageType.image),
              ),
              _MediaGrid(
                messages: widget.chatService
                    .getMediaMessages(_conversation.id, MessageType.video),
              ),
              _MediaGrid(
                messages: widget.chatService
                    .getMediaMessages(_conversation.id, MessageType.voice),
              ),
              _MediaGrid(
                messages: widget.chatService
                    .getMediaMessages(_conversation.id, MessageType.file),
              ),
              _MediaGrid(
                messages: widget.chatService
                    .getMediaMessages(_conversation.id, MessageType.music),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileAction {
  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;
}

/// Compact bottom bar that expands upward into the full actions list —
/// same idea as the pinned-messages dropdown.
class _ProfileActionsSheet extends StatefulWidget {
  const _ProfileActionsSheet({required this.actions});

  final List<_ProfileAction> actions;

  @override
  State<_ProfileActionsSheet> createState() => _ProfileActionsSheetState();
}

class _ProfileActionsSheetState extends State<_ProfileActionsSheet> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = context.strings;

    return Material(
      elevation: 6,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.tune,
                        size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        strings.profileActions,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    Text(
                      '${widget.actions.length}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: widget.actions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final action = widget.actions[index];
                          final color = action.isDestructive
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary;
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                  color: color.withValues(alpha: 0.35)),
                            ),
                            leading: Icon(action.icon, color: color),
                            title: Text(
                              action.label,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () {
                              setState(() => _expanded = false);
                              action.onPressed();
                            },
                          );
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaGrid extends StatelessWidget {
  const _MediaGrid({required this.messages});
  final List<Message> messages;

  @override
  Widget build(BuildContext context) {
    // Expand albums into individual tiles so grouped photos are all visible.
    final items = <_MediaGridItem>[];
    for (final message in messages) {
      final media = MediaPayload.tryParse(message.content);
      if (media == null) continue;
      final isImage = message.type == MessageType.image ||
          message.type == MessageType.sticker ||
          message.type == MessageType.gif;
      for (final url in media.allUrls) {
        items.add(_MediaGridItem(
          url: url,
          isImage: isImage,
          name: media.name,
          type: message.type,
        ));
      }
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const StretchCatSilhouette(width: 200),
            const SizedBox(height: 16),
            Text(
              context.strings.noMedia,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      );
    }

    final imageUrls = [
      for (final item in items)
        if (item.isImage) item.url,
    ];

    return Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: StretchCatSilhouette(width: 220, opacity: 0.12),
            ),
          ),
        ),
        GridView.builder(
          padding: const EdgeInsets.all(6),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 3,
            mainAxisSpacing: 3,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];

            return InkWell(
              onTap: item.isImage
                  ? () => MediaViewerScreen.open(
                        context,
                        urls: imageUrls,
                        initialIndex: imageUrls.indexOf(item.url),
                      )
                  : () => launchUrl(
                        Uri.parse(item.url),
                        mode: LaunchMode.externalApplication,
                      ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: item.isImage
                      ? Image.network(item.url, fit: BoxFit.cover)
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(
                              item.name.isNotEmpty
                                  ? item.name
                                  : messageTypeLabel(item.type),
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
        ),
      ],
    );
  }
}

class _MediaGridItem {
  const _MediaGridItem({
    required this.url,
    required this.isImage,
    required this.name,
    required this.type,
  });

  final String url;
  final bool isImage;
  final String name;
  final MessageType type;
}
