import 'plus_cosmetics.dart';

/// Job-search status of a developer on the platform.
enum DevStatus {
  none('none'),
  lookingForTeam('looking_for_team'),
  lookingForMembers('looking_for_members'),
  openToOffers('open_to_offers'),
  doNotDisturb('do_not_disturb');

  const DevStatus(this.dbValue);

  final String dbValue;

  static DevStatus fromDb(String? value) => DevStatus.values.firstWhere(
        (s) => s.dbValue == value,
        orElse: () => DevStatus.none,
      );
}

/// Self-reported experience level.
enum ExperienceLevel {
  junior('junior'),
  middle('middle'),
  senior('senior'),
  lead('lead');

  const ExperienceLevel(this.dbValue);

  final String dbValue;

  static ExperienceLevel? fromDb(String? value) {
    for (final level in ExperienceLevel.values) {
      if (level.dbValue == value) return level;
    }
    return null;
  }
}

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
    this.devStatus = DevStatus.none,
    this.skills = const [],
    this.experienceLevel,
    this.githubUrl,
    this.portfolioUrl,
    this.city,
    this.avatarFrame = AvatarFrameId.none,
    this.nickColorId,
    this.isPlus = false,
    this.plusUntil,
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
  final DevStatus devStatus;
  final List<String> skills;
  final ExperienceLevel? experienceLevel;
  final String? githubUrl;
  final String? portfolioUrl;
  final String? city;
  final AvatarFrameId avatarFrame;
  final String? nickColorId;
  final bool isPlus;
  final DateTime? plusUntil;

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
    DevStatus? devStatus,
    List<String>? skills,
    ExperienceLevel? experienceLevel,
    String? githubUrl,
    String? portfolioUrl,
    String? city,
    AvatarFrameId? avatarFrame,
    String? nickColorId,
    bool? isPlus,
    DateTime? plusUntil,
    bool clearAvatar = false,
    bool clearCustomWallpaper = false,
    bool clearBirthday = false,
    bool clearExperienceLevel = false,
    bool clearNickColor = false,
    bool clearPlusUntil = false,
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
      devStatus: devStatus ?? this.devStatus,
      skills: skills ?? this.skills,
      experienceLevel: clearExperienceLevel
          ? null
          : (experienceLevel ?? this.experienceLevel),
      githubUrl: githubUrl ?? this.githubUrl,
      portfolioUrl: portfolioUrl ?? this.portfolioUrl,
      city: city ?? this.city,
      avatarFrame: avatarFrame ?? this.avatarFrame,
      nickColorId: clearNickColor ? null : (nickColorId ?? this.nickColorId),
      isPlus: isPlus ?? this.isPlus,
      plusUntil: clearPlusUntil ? null : (plusUntil ?? this.plusUntil),
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
        'devStatus': devStatus.dbValue,
        'skills': skills,
        'experienceLevel': experienceLevel?.dbValue,
        'githubUrl': githubUrl,
        'portfolioUrl': portfolioUrl,
        'city': city,
        'avatarFrame': avatarFrame.dbValue,
        'nickColorId': nickColorId,
        'isPlus': isPlus,
        'plusUntil': plusUntil?.toIso8601String(),
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
      devStatus: DevStatus.fromDb(json['devStatus'] as String?),
      skills: _parseSkills(json['skills']),
      experienceLevel: ExperienceLevel.fromDb(json['experienceLevel'] as String?),
      githubUrl: json['githubUrl'] as String?,
      portfolioUrl: json['portfolioUrl'] as String?,
      city: json['city'] as String?,
      avatarFrame: AvatarFrameId.fromDb(json['avatarFrame'] as String?),
      nickColorId: json['nickColorId'] as String?,
      isPlus: json['isPlus'] as bool? ?? false,
      plusUntil: json['plusUntil'] != null
          ? DateTime.tryParse(json['plusUntil'] as String)
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
      email: row['email'] as String? ?? '',
      status: row['status'] as String? ?? '',
      avatarPath: row['avatar_url'] as String?,
      avatarEmoji: row['avatar_emoji'] as String?,
      profileWallpaperId: row['profile_wallpaper_id'] as String? ?? 'blue',
      customWallpaperPath: row['custom_wallpaper_url'] as String?,
      birthday: birthday,
      devStatus: DevStatus.fromDb(row['dev_status'] as String?),
      skills: _parseSkills(row['skills']),
      experienceLevel: ExperienceLevel.fromDb(row['experience_level'] as String?),
      githubUrl: row['github_url'] as String?,
      portfolioUrl: row['portfolio_url'] as String?,
      city: row['city'] as String?,
      avatarFrame: AvatarFrameId.fromDb(row['avatar_frame'] as String?),
      nickColorId: row['nick_color'] as String?,
      isPlus: row['is_plus'] as bool? ?? false,
      plusUntil: row['plus_until'] != null
          ? DateTime.tryParse(row['plus_until'] as String)
          : null,
    );
  }

  Map<String, dynamic> toProfileUpdate() => {
        'login': login,
        'status': status,
        'avatar_emoji': avatarEmoji,
        'avatar_url': avatarPath,
        'profile_wallpaper_id': profileWallpaperId,
        'custom_wallpaper_url': customWallpaperPath,
        'birthday': birthday?.toIso8601String().split('T').first,
        'dev_status': devStatus.dbValue,
        'skills': skills,
        'experience_level': experienceLevel?.dbValue,
        'github_url': _blankToNull(githubUrl),
        'portfolio_url': _blankToNull(portfolioUrl),
        'city': _blankToNull(city),
        'avatar_frame': avatarFrame.dbValue,
        'nick_color': nickColorId,
      };

  static List<String> _parseSkills(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const [];
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
