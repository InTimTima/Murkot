class User {
  const User({
    required this.login,
    required this.email,
    this.status = '',
    this.avatarPath,
  });

  final String login;
  final String email;
  final String status;
  final String? avatarPath;

  User copyWith({
    String? login,
    String? email,
    String? status,
    String? avatarPath,
    bool clearAvatar = false,
  }) {
    return User(
      login: login ?? this.login,
      email: email ?? this.email,
      status: status ?? this.status,
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
    );
  }

  Map<String, dynamic> toJson() => {
        'login': login,
        'email': email,
        'status': status,
        'avatarPath': avatarPath,
      };

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      login: json['login'] as String,
      email: json['email'] as String,
      status: json['status'] as String? ?? '',
      avatarPath: json['avatarPath'] as String?,
    );
  }
}
