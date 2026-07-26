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
      };

  factory Message.fromJson(Map<String, dynamic> json) {
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
  };
}
