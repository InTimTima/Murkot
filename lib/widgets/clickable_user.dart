import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/conversation.dart';
import '../services/blacklist_service.dart';
import '../services/chat_service.dart';
import '../services/presence_service.dart';
import '../services/settings_service.dart';
import '../utils/main_tab_bus.dart';
import '../widgets/avatar_display.dart';
import '../screens/public_profile_screen.dart';
import '../screens/stranger_profile_screen.dart';

/// Opens profile for any login. Used for avatar/nick taps everywhere.
Future<void> openUserProfile(
  BuildContext context, {
  required String login,
  required ChatService chatService,
  required BlacklistService blacklistService,
  required PresenceService presenceService,
  required String currentUserLogin,
  required SettingsService settingsService,
}) async {
  final trimmed = login.trim();
  if (trimmed.isEmpty) return;
  if (trimmed.toLowerCase() == currentUserLogin.toLowerCase()) {
    mainTabIndex.value = MainTabs.profile;
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    return;
  }
  try {
    final directConvs = chatService.getConversations(ConversationType.direct).where((c) => c.name.toLowerCase() == trimmed.toLowerCase()).toList();
    if (directConvs.isNotEmpty) {
      final existing = directConvs.first;
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StrangerProfileScreen(conversation: existing, chatService: chatService, blacklistService: blacklistService, currentUserLogin: currentUserLogin, settingsService: settingsService)));
      return;
    }
    final users = await chatService.searchUsers(trimmed);
    final exact = users.where((u) => u.login.toLowerCase() == trimmed.toLowerCase());
    if (exact.isEmpty) {
      if (!context.mounted) return;
      // Fallback to public profile
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PublicProfileScreen(login: trimmed, chatService: chatService, blacklistService: blacklistService, presenceService: presenceService, currentUserLogin: currentUserLogin, settingsService: settingsService)));
      return;
    }
    final conversation = await chatService.openDirectChat(exact.first);
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StrangerProfileScreen(conversation: conversation, chatService: chatService, blacklistService: blacklistService, currentUserLogin: currentUserLogin, settingsService: settingsService)));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.strings.openProfileFailed(e))));
  }
}

class ClickableAvatar extends StatelessWidget {
  const ClickableAvatar({
    super.key,
    required this.login,
    this.avatarPath,
    this.avatarEmoji,
    required this.chatService,
    required this.blacklistService,
    required this.presenceService,
    required this.currentUserLogin,
    required this.settingsService,
    this.radius = 18,
  });

  final String login;
  final String? avatarPath;
  final String? avatarEmoji;
  final ChatService chatService;
  final BlacklistService blacklistService;
  final PresenceService presenceService;
  final String currentUserLogin;
  final SettingsService settingsService;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openUserProfile(context, login: login, chatService: chatService, blacklistService: blacklistService, presenceService: presenceService, currentUserLogin: currentUserLogin, settingsService: settingsService),
      child: AvatarDisplay(name: login, avatarPath: avatarPath, avatarEmoji: avatarEmoji, radius: radius),
    );
  }
}

class ClickableNick extends StatelessWidget {
  const ClickableNick({
    super.key,
    required this.login,
    required this.chatService,
    required this.blacklistService,
    required this.presenceService,
    required this.currentUserLogin,
    required this.settingsService,
    this.style,
    this.maxLines,
  });

  final String login;
  final ChatService chatService;
  final BlacklistService blacklistService;
  final PresenceService presenceService;
  final String currentUserLogin;
  final SettingsService settingsService;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openUserProfile(context, login: login, chatService: chatService, blacklistService: blacklistService, presenceService: presenceService, currentUserLogin: currentUserLogin, settingsService: settingsService),
      child: Text(login, style: style, maxLines: maxLines, overflow: maxLines != null ? TextOverflow.ellipsis : null),
    );
  }
}
