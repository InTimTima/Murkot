import 'user_preview.dart';

/// A project published on the showcase.
class Project {
  const Project({
    required this.id,
    required this.authorId,
    required this.author,
    required this.name,
    required this.description,
    required this.stack,
    required this.lookingFor,
    required this.createdAt,
    this.demoUrl,
    this.repoUrl,
    this.avatarUrl,
    this.imageUrls = const [],
  });

  final String id;
  final String authorId;
  final UserPreview author;
  final String name;
  final String description;
  final List<String> stack;

  /// Roles the team still needs (e.g. "Backend", "UI/UX").
  final List<String> lookingFor;
  final String? demoUrl;
  final String? repoUrl;
  final String? avatarUrl;
  final List<String> imageUrls;
  final DateTime createdAt;

  /// Parses a row from `.from('projects').select('*, author:profiles(...)')`.
  factory Project.fromRow(Map<String, dynamic> row) {
    final authorRow = row['author'];
    return Project(
      id: row['id'] as String,
      authorId: row['author_id'] as String,
      author: authorRow is Map
          ? UserPreview.fromRow(Map<String, dynamic>.from(authorRow))
          : UserPreview(id: row['author_id'] as String, login: '?'),
      name: row['name'] as String,
      description: row['description'] as String? ?? '',
      stack: _parseTags(row['stack']),
      lookingFor: _parseTags(row['looking_for']),
      demoUrl: row['demo_url'] as String?,
      repoUrl: row['repo_url'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      imageUrls: _parseTags(row['image_urls']),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  static List<String> _parseTags(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const [];
  }
}
