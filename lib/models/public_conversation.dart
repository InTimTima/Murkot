/// Lightweight search result for public groups/channels.
class PublicConversationPreview {
  const PublicConversationPreview({
    required this.id,
    required this.type,
    required this.name,
    this.description = '',
    this.avatarEmoji,
    this.avatarUrl,
    this.category,
    this.memberCount = 0,
    this.isMember = false,
  });

  final String id;
  final String type;
  final String name;
  final String description;
  final String? avatarEmoji;
  final String? avatarUrl;
  final String? category;
  final int memberCount;
  final bool isMember;

  factory PublicConversationPreview.fromRow(Map<String, dynamic> row) {
    return PublicConversationPreview(
      id: row['id'] as String,
      type: row['type'] as String? ?? 'group',
      name: row['name'] as String? ?? '',
      description: row['description'] as String? ?? '',
      avatarEmoji: row['avatar_emoji'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      category: row['category'] as String?,
      memberCount: (row['member_count'] as num?)?.toInt() ?? 0,
      isMember: row['is_member'] as bool? ?? false,
    );
  }
}
