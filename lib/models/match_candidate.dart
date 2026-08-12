import 'user.dart';
import 'user_preview.dart';

/// A person shown in the matching feed or in the mutual-matches list.
class MatchCandidate {
  const MatchCandidate({
    required this.user,
    this.sharedSkills = 0,
    this.matchedAt,
  });

  final User user;
  final int sharedSkills;
  final DateTime? matchedAt;

  UserPreview get preview => UserPreview(
        id: user.id,
        login: user.login,
        status: user.status,
        avatarEmoji: user.avatarEmoji,
        avatarUrl: user.avatarPath,
      );

  factory MatchCandidate.fromRow(Map<String, dynamic> row) {
    DateTime? matchedAt;
    final rawMatched = row['matched_at'];
    if (rawMatched is String && rawMatched.isNotEmpty) {
      matchedAt = DateTime.tryParse(rawMatched)?.toLocal();
    }

    return MatchCandidate(
      user: User.fromProfileRow(row),
      sharedSkills: (row['shared_skills'] as num?)?.toInt() ?? 0,
      matchedAt: matchedAt,
    );
  }
}
