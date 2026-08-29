import 'plus_cosmetics.dart';

class UserPreview {
  const UserPreview({
    required this.id,
    required this.login,
    this.status = '',
    this.avatarEmoji,
    this.avatarUrl,
    this.isBot = false,
    this.city,
    this.avatarFrame = AvatarFrameId.none,
    this.nickColorId,
    this.isPlus = false,
  });

  final String id;
  final String login;
  final String status;
  final String? avatarEmoji;
  final String? avatarUrl;
  final bool isBot;
  final String? city;
  final AvatarFrameId avatarFrame;
  final String? nickColorId;
  final bool isPlus;

  factory UserPreview.fromRow(Map<String, dynamic> row) {
    final cityRaw = row['city'] as String?;
    final city = cityRaw?.trim();
    return UserPreview(
      id: row['id'] as String,
      login: row['login'] as String,
      status: row['status'] as String? ?? '',
      avatarEmoji: row['avatar_emoji'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      isBot: row['is_bot'] as bool? ?? false,
      city: (city == null || city.isEmpty) ? null : city,
      avatarFrame: AvatarFrameId.fromDb(row['avatar_frame'] as String?),
      nickColorId: row['nick_color'] as String?,
      isPlus: row['is_plus'] as bool? ?? false,
    );
  }
}
