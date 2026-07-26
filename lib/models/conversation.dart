enum ConversationType { direct, group, channel }

class Conversation {
  const Conversation({
    required this.id,
    required this.type,
    required this.name,
    this.avatarPath,
    this.avatarEmoji,
    this.lastMessage = '',
    this.lastMessageSender,
    required this.lastActivity,
    this.isOnline = false,
    this.onlineCount = 0,
    this.subscriberCount = 0,
    this.memberIds = const [],
    this.isAdmin = false,
    this.description = '',
    this.contactStatus = '',
    this.contactBirthday,
    this.pinnedForAllIds = const [],
    this.typingUsers = const [],
  });

  final String id;
  final ConversationType type;
  final String name;
  final String? avatarPath;
  final String? avatarEmoji;
  final String lastMessage;
  final String? lastMessageSender;
  final DateTime lastActivity;
  final bool isOnline;
  final int onlineCount;
  final int subscriberCount;
  final List<String> memberIds;
  final bool isAdmin;
  final String description;
  final String contactStatus;
  final DateTime? contactBirthday;
  final List<String> pinnedForAllIds;
  final List<String> typingUsers;

  Conversation copyWith({
    String? id,
    ConversationType? type,
    String? name,
    String? avatarPath,
    String? avatarEmoji,
    String? lastMessage,
    String? lastMessageSender,
    DateTime? lastActivity,
    bool? isOnline,
    int? onlineCount,
    int? subscriberCount,
    List<String>? memberIds,
    bool? isAdmin,
    String? description,
    String? contactStatus,
    DateTime? contactBirthday,
    List<String>? pinnedForAllIds,
    List<String>? typingUsers,
    bool clearAvatar = false,
  }) {
    return Conversation(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSender: lastMessageSender ?? this.lastMessageSender,
      lastActivity: lastActivity ?? this.lastActivity,
      isOnline: isOnline ?? this.isOnline,
      onlineCount: onlineCount ?? this.onlineCount,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      memberIds: memberIds ?? this.memberIds,
      isAdmin: isAdmin ?? this.isAdmin,
      description: description ?? this.description,
      contactStatus: contactStatus ?? this.contactStatus,
      contactBirthday: contactBirthday ?? this.contactBirthday,
      pinnedForAllIds: pinnedForAllIds ?? this.pinnedForAllIds,
      typingUsers: typingUsers ?? this.typingUsers,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'name': name,
        'avatarPath': avatarPath,
        'avatarEmoji': avatarEmoji,
        'lastMessage': lastMessage,
        'lastMessageSender': lastMessageSender,
        'lastActivity': lastActivity.toIso8601String(),
        'isOnline': isOnline,
        'onlineCount': onlineCount,
        'subscriberCount': subscriberCount,
        'memberIds': memberIds,
        'isAdmin': isAdmin,
        'description': description,
        'contactStatus': contactStatus,
        'contactBirthday': contactBirthday?.toIso8601String(),
        'pinnedForAllIds': pinnedForAllIds,
        'typingUsers': typingUsers,
      };

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      type: ConversationType.values[json['type'] as int],
      name: json['name'] as String,
      avatarPath: json['avatarPath'] as String?,
      avatarEmoji: json['avatarEmoji'] as String?,
      lastMessage: json['lastMessage'] as String? ?? '',
      lastMessageSender: json['lastMessageSender'] as String?,
      lastActivity: DateTime.parse(json['lastActivity'] as String),
      isOnline: json['isOnline'] as bool? ?? false,
      onlineCount: json['onlineCount'] as int? ?? 0,
      subscriberCount: json['subscriberCount'] as int? ?? 0,
      memberIds: (json['memberIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isAdmin: json['isAdmin'] as bool? ?? false,
      description: json['description'] as String? ?? '',
      contactStatus: json['contactStatus'] as String? ?? '',
      contactBirthday: json['contactBirthday'] != null
          ? DateTime.parse(json['contactBirthday'] as String)
          : null,
      pinnedForAllIds: (json['pinnedForAllIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      typingUsers: (json['typingUsers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }
}
