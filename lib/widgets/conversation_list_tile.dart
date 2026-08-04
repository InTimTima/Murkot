import 'package:flutter/material.dart';

import '../models/conversation.dart';
import '../widgets/avatar_display.dart';

class ConversationListTile extends StatelessWidget {
  const ConversationListTile({
    super.key,
    required this.conversation,
    required this.onTapBody,
    required this.onTapAvatar,
    this.isOnline = false,
  });

  final Conversation conversation;
  final VoidCallback onTapBody;
  final VoidCallback onTapAvatar;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTapBody,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            GestureDetector(
              onTap: onTapAvatar,
              child: Stack(
                children: [
                  AvatarDisplay(
                    name: conversation.name,
                    avatarPath: conversation.avatarPath,
                    avatarEmoji: conversationAvatarEmoji(conversation),
                    radius: 26,
                  ),
                  if (isOnline)
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (conversation.lastMessage.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _subtitle {
    if (conversation.lastMessageSender != null &&
        conversation.type != ConversationType.direct) {
      return '${conversation.lastMessageSender}: ${conversation.lastMessage}';
    }
    return conversation.lastMessage;
  }
}
