class UserPreview {
  const UserPreview({
    required this.id,
    required this.login,
    this.status = '',
    this.avatarEmoji,
    this.avatarUrl,
    this.isBot = false,
  });

  final String id;
  final String login;
  final String status;
  final String? avatarEmoji;
  final String? avatarUrl;
  final bool isBot;

  factory UserPreview.fromRow(Map<String, dynamic> row) {
    return UserPreview(
      id: row['id'] as String,
      login: row['login'] as String,
      status: row['status'] as String? ?? '',
      avatarEmoji: row['avatar_emoji'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      isBot: row['is_bot'] as bool? ?? false,
    );
  }
}
