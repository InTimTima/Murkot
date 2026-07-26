import 'dart:io';

import 'package:flutter/material.dart';

import '../models/conversation.dart';

class AvatarDisplay extends StatelessWidget {
  const AvatarDisplay({
    super.key,
    this.avatarPath,
    this.avatarEmoji,
    required this.name,
    this.radius = 26,
    this.fontSize,
  });

  final String? avatarPath;
  final String? avatarEmoji;
  final String name;
  final double radius;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFile = avatarPath != null && File(avatarPath!).existsSync();

    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      backgroundImage: hasFile ? FileImage(File(avatarPath!)) : null,
      child: !hasFile
          ? Text(
              avatarEmoji ?? (name.isNotEmpty ? name[0].toUpperCase() : '?'),
              style: TextStyle(
                fontSize: fontSize ?? radius * 0.85,
                fontWeight: FontWeight.bold,
                color: avatarEmoji != null
                    ? null
                    : theme.colorScheme.onPrimaryContainer,
              ),
            )
          : null,
    );
  }
}

String conversationAvatarEmoji(Conversation conversation) {
  return conversation.avatarEmoji ?? pickRandomEmoji(conversation.name.hashCode);
}

// Re-export for convenience
String pickRandomEmoji([int? seed]) {
  const emojis = [
    '😀', '🦊', '🐱', '🐶', '🌟', '🎮', '🎨', '🔥',
    '💎', '🚀', '🌈', '🎭', '🎵', '⚡', '🍀', '🦄',
  ];
  if (seed != null) return emojis[seed.abs() % emojis.length];
  return emojis[DateTime.now().millisecondsSinceEpoch % emojis.length];
}
