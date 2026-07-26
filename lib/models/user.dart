class User {
  const User({
    required this.login,
    required this.email,
    this.status = '',
    this.avatarPath,
    this.avatarEmoji,
    this.profileWallpaperId = 'blue',
    this.customWallpaperPath,
    this.birthday,
  });

  final String login;
  final String email;
  final String status;
  final String? avatarPath;
  final String? avatarEmoji;
  final String profileWallpaperId;
  final String? customWallpaperPath;
  final DateTime? birthday;

  User copyWith({
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
}
