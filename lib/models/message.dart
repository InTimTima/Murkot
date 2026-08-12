import 'media_payload.dart';
import 'system_payload.dart';

enum MessageType {
  text,
  voice,
  video,
  image,
  music,
  sticker,
  emoji,
  gif,
  file,

  /// Service notice, e.g. "X добавил Y" — rendered as a centered pill.
  system,
}

enum MessageSendStatus {
  sent,
  sending,
  failed,
}

class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.content,
    required this.timestamp,
    this.reactions = const {},
    this.isEdited = false,
    this.isDeletedForAll = false,
    this.deletedForMe = false,
    this.isRead = false,
    this.viewCount = 0,
    this.senderEmoji,
    this.replyToId,
    this.replyToSender,
    this.replyToContent,
    this.sendStatus = MessageSendStatus.sent,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final MessageType type;
  final String content;
  final DateTime timestamp;
  final Map<String, String> reactions;
  final bool isEdited;
  final bool isDeletedForAll;
  final bool deletedForMe;
  final bool isRead;
  final int viewCount;
  final String? senderEmoji;
  final String? replyToId;
  final String? replyToSender;
  final String? replyToContent;
  final MessageSendStatus sendStatus;

  bool get isLocalPending => id.startsWith('local_');

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    MessageType? type,
    String? content,
    DateTime? timestamp,
    Map<String, String>? reactions,
    bool? isEdited,
    bool? isDeletedForAll,
    bool? deletedForMe,
    bool? isRead,
    int? viewCount,
    String? senderEmoji,
    String? replyToId,
    String? replyToSender,
    String? replyToContent,
    MessageSendStatus? sendStatus,
    bool clearReply = false,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      type: type ?? this.type,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      reactions: reactions ?? this.reactions,
      isEdited: isEdited ?? this.isEdited,
      isDeletedForAll: isDeletedForAll ?? this.isDeletedForAll,
      deletedForMe: deletedForMe ?? this.deletedForMe,
      isRead: isRead ?? this.isRead,
      viewCount: viewCount ?? this.viewCount,
      senderEmoji: senderEmoji ?? this.senderEmoji,
      replyToId: clearReply ? null : (replyToId ?? this.replyToId),
      replyToSender: clearReply ? null : (replyToSender ?? this.replyToSender),
      replyToContent:
          clearReply ? null : (replyToContent ?? this.replyToContent),
      sendStatus: sendStatus ?? this.sendStatus,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'senderId': senderId,
        'senderName': senderName,
        'type': type.index,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'reactions': reactions,
        'isEdited': isEdited,
        'isDeletedForAll': isDeletedForAll,
        'deletedForMe': deletedForMe,
        'isRead': isRead,
        'viewCount': viewCount,
        'senderEmoji': senderEmoji,
        'replyToId': replyToId,
        'replyToSender': replyToSender,
        'replyToContent': replyToContent,
        'sendStatus': sendStatus.index,
      };

  factory Message.fromJson(Map<String, dynamic> json) {
    final statusIndex = json['sendStatus'] as int?;
    return Message(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      type: MessageType.values[json['type'] as int],
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      reactions: (json['reactions'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as String)) ??
          {},
      isEdited: json['isEdited'] as bool? ?? false,
      isDeletedForAll: json['isDeletedForAll'] as bool? ?? false,
      deletedForMe: json['deletedForMe'] as bool? ?? false,
      isRead: json['isRead'] as bool? ?? false,
      viewCount: json['viewCount'] as int? ?? 0,
      senderEmoji: json['senderEmoji'] as String?,
      replyToId: json['replyToId'] as String?,
      replyToSender: json['replyToSender'] as String?,
      replyToContent: json['replyToContent'] as String?,
      sendStatus: statusIndex != null &&
              statusIndex >= 0 &&
              statusIndex < MessageSendStatus.values.length
          ? MessageSendStatus.values[statusIndex]
          : MessageSendStatus.sent,
    );
  }
}

String messageTypeLabel(MessageType type) {
  return switch (type) {
    MessageType.text => '',
    MessageType.voice => '🎤 Голосовое',
    MessageType.video => '🎬 Видео',
    MessageType.image => '📷 Фото',
    MessageType.music => '🎵 Музыка',
    MessageType.sticker => '🎭 Стикер',
    MessageType.emoji => '😀 Эмодзи',
    MessageType.gif => 'GIF',
    MessageType.file => '📎 Файл',
    MessageType.system => '',
  };
}

String truncateChatPreview(String? value, {int maxChars = 48}) {
  final text = (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length <= maxChars) return text;
  return '${text.substring(0, maxChars).trimRight()}…';
}

String messagePreviewText(Message message, {int maxChars = 48}) {
  if (message.isDeletedForAll) return 'Сообщение удалено';
  final String raw;
  if (message.type == MessageType.system) {
    raw = SystemPayload.tryParse(message.content)?.text ?? message.content;
  } else if (message.type == MessageType.text) {
    raw = message.content;
  } else {
    final label = messageTypeLabel(message.type);
    final caption = MediaPayload.tryParse(message.content)?.caption;
    if (caption != null && caption.isNotEmpty) {
      raw = '$label · $caption';
    } else {
      raw = label.isEmpty ? message.content : label;
    }
  }
  return truncateChatPreview(raw, maxChars: maxChars);
}
