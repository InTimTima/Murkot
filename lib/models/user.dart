class User {
  const User({
    required this.id,
    required this.login,
    required this.email,
    this.status = '',
    this.avatarPath,
    this.avatarEmoji,
    this.profileWallpaperId = 'blue',
    this.customWallpaperPath,
    this.birthday,
  });

  final String id;
  final String login;
  final String email;
  final String status;
  final String? avatarPath;
  final String? avatarEmoji;
  final String profileWallpaperId;
  final String? customWallpaperPath;
  final DateTime? birthday;

  User copyWith({
    String? id,
    String? login,
    String? email,
    String? status,
    String? avatarPath,
    String? avatarEmoji,
    String? profileWallpaperId,
    String? customWallpaperPath,
    DateTime? birthday,
    bool clearAvatar = false,
    bool clearCustomWallpaper = false,
    bool clearBirthday = false,
  }) {
    return User(
      id: id ?? this.id,
      login: login ?? this.login,
      email: email ?? this.email,
      status: status ?? this.status,
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      profileWallpaperId: profileWallpaperId ?? this.profileWallpaperId,
      customWallpaperPath: clearCustomWallpaper
          ? null
          : (customWallpaperPath ?? this.customWallpaperPath),
      birthday: clearBirthday ? null : (birthday ?? this.birthday),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'login': login,
        'email': email,
        'status': status,
        'avatarPath': avatarPath,
        'avatarEmoji': avatarEmoji,
        'profileWallpaperId': profileWallpaperId,
        'customWallpaperPath': customWallpaperPath,
        'birthday': birthday?.toIso8601String(),
      };

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String? ?? '',
      login: json['login'] as String,
      email: json['email'] as String,
      status: json['status'] as String? ?? '',
      avatarPath: json['avatarPath'] as String?,
      avatarEmoji: json['avatarEmoji'] as String?,
      profileWallpaperId: json['profileWallpaperId'] as String? ?? 'blue',
      customWallpaperPath: json['customWallpaperPath'] as String?,
      birthday: json['birthday'] != null
          ? DateTime.parse(json['birthday'] as String)
          : null,
    );
  }

  factory User.fromProfileRow(Map<String, dynamic> row) {
    DateTime? birthday;
    final rawBirthday = row['birthday'];
    if (rawBirthday is String && rawBirthday.isNotEmpty) {
      birthday = DateTime.tryParse(rawBirthday);
    }

    return User(
      id: row['id'] as String,
      login: row['login'] as String,
      email: row['email'] as String,
      status: row['status'] as String? ?? '',
      avatarPath: row['avatar_url'] as String?,
      avatarEmoji: row['avatar_emoji'] as String?,
      profileWallpaperId: row['profile_wallpaper_id'] as String? ?? 'blue',
      customWallpaperPath: row['custom_wallpaper_url'] as String?,
      birthday: birthday,
    );
  }

  Map<String, dynamic> toProfileUpdate() => {
        'login': login,
        'email': email,
        'status': status,
        'avatar_emoji': avatarEmoji,
        'avatar_url': avatarPath,
        'profile_wallpaper_id': profileWallpaperId,
        'custom_wallpaper_url': customWallpaperPath,
        'birthday': birthday?.toIso8601String().split('T').first,
      };
}
