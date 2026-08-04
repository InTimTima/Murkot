import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/user_preview.dart';
import '../services/chat_service.dart';
import '../widgets/avatar_display.dart';

Future<UserPreview?> showUserSearchSheet({
  required BuildContext context,
  required ChatService chatService,
}) {
  return showModalBottomSheet<UserPreview>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => UserSearchSheet(chatService: chatService),
  );
}

class UserSearchSheet extends StatefulWidget {
  const UserSearchSheet({super.key, required this.chatService});

  final ChatService chatService;

  @override
  State<UserSearchSheet> createState() => _UserSearchSheetState();
}

class _UserSearchSheetState extends State<UserSearchSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<UserPreview> _results = const [];
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
      final users = await widget.chatService.searchUsers(q);
      if (!mounted) return;
      setState(() {
        _results = users;
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
                strings.findUsers,
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
                  hintText: strings.searchUsersHint,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.45,
                ),
                leading: const AvatarDisplay(
                  name: ChatService.botLogin,
                  avatarEmoji: '🤖',
                  radius: 22,
                ),
                title: Text(strings.chatWithBot),
                subtitle: Text(strings.botSubtitle),
                onTap: () => Navigator.pop(
                  context,
                  const UserPreview(
                    id: ChatService.botUserId,
                    login: ChatService.botLogin,
                    status: 'Всегда на связи',
                    avatarEmoji: '🤖',
                    isBot: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
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
                                strings.usersNotFound,
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
                                final user = _results[index];
                                return ListTile(
                                  leading: AvatarDisplay(
                                    name: user.login,
                                    avatarPath: user.avatarUrl,
                                    avatarEmoji: user.avatarEmoji,
                                    radius: 22,
                                  ),
                                  title: Row(
                                    children: [
                                      Flexible(child: Text(user.login)),
                                      if (user.isBot) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'BOT',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Text(
                                    user.status.isEmpty
                                        ? strings.noStatus
                                        : user.status,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => Navigator.pop(context, user),
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
