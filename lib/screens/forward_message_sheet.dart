import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../widgets/avatar_display.dart';

Future<void> showForwardMessageSheet({
  required BuildContext context,
  required ChatService chatService,
  required Message message,
}) async {
  final strings = context.strings;
  final target = await showModalBottomSheet<Conversation>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final chats = [
        ...chatService.getConversations(ConversationType.direct),
        ...chatService.getConversations(ConversationType.group),
        ...chatService.getConversations(ConversationType.channel).where(
              (c) => chatService.canSendMessages(c),
            ),
      ];

      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                strings.forwardTo,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            Expanded(
              child: chats.isEmpty
                  ? Center(child: Text(strings.emptyList))
                  : ListView.separated(
                      itemCount: chats.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final conversation = chats[index];
                        return ListTile(
                          leading: AvatarDisplay(
                            name: conversation.name,
                            avatarPath: conversation.avatarPath,
                            avatarEmoji: conversationAvatarEmoji(conversation),
                            radius: 22,
                          ),
                          title: Text(conversation.name),
                          subtitle: Text(switch (conversation.type) {
                            ConversationType.direct => strings.chats,
                            ConversationType.group => strings.groups,
                            ConversationType.channel => strings.channels,
                          }),
                          onTap: () => Navigator.pop(context, conversation),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );

  if (target == null || !context.mounted) return;

  try {
    await chatService.forwardMessage(
      message: message,
      targetConversationId: target.id,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.messageForwarded)),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$e')),
    );
  }
}
