import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/project.dart';

/// Loads and mutates the project showcase.
class ProjectsService extends ChangeNotifier {
  ProjectsService({required String userId}) : _userId = userId;

  final String _userId;
  final _client = Supabase.instance.client;

  static const _authorSelect =
      '*, author:profiles!projects_author_id_fkey(id, login, status, avatar_emoji, avatar_url, is_bot)';

  List<Project> _projects = const [];
  bool _loading = false;
  String? _error;
  String? _skillFilter;

  bool get isLoading => _loading;
  String? get error => _error;
  String? get skillFilter => _skillFilter;

  /// Projects matching the current stack filter, newest first.
  List<Project> get projects {
    final skill = _skillFilter;
    if (skill == null) return _projects;
    return _projects
        .where(
            (p) => p.stack.any((s) => s.toLowerCase() == skill.toLowerCase()))
        .toList();
  }

  /// All distinct stack tags across loaded projects (for filter chips).
  List<String> get availableSkills {
    final seen = <String, String>{};
    for (final project in _projects) {
      for (final tag in project.stack) {
        seen.putIfAbsent(tag.toLowerCase(), () => tag);
      }
    }
    final tags = seen.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return tags;
  }

  bool isMine(Project project) => project.authorId == _userId;

  void setSkillFilter(String? skill) {
    if (_skillFilter == skill) return;
    _skillFilter = skill;
    notifyListeners();
  }

  bool get hasActiveFilters => _skillFilter != null;

  void clearFilters() {
    if (_skillFilter == null) return;
    _skillFilter = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final rows = await _client
          .from('projects')
          .select(_authorSelect)
          .order('created_at', ascending: false)
          .limit(100);

      _projects = (rows as List)
          .map((row) => Project.fromRow(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e) {
      debugPrint('Projects refresh failed: $e');
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Returns an error message, or null on success.
  Future<String?> createProject({
    required String name,
    required String description,
    required List<String> stack,
    required List<String> lookingFor,
    String? demoUrl,
    String? repoUrl,
  }) async {
    try {
      await _client.from('projects').insert({
        'author_id': _userId,
        'name': name,
        'description': description,
        'stack': stack,
        'looking_for': lookingFor,
        'demo_url': (demoUrl != null && demoUrl.isNotEmpty) ? demoUrl : null,
        'repo_url': (repoUrl != null && repoUrl.isNotEmpty) ? repoUrl : null,
      });
      await refresh();
      return null;
    } catch (e) {
      debugPrint('Create project failed: $e');
      return e.toString();
    }
  }

  /// Returns an error message, or null on success.
  Future<String?> updateProject({
    required String id,
    required String name,
    required String description,
    required List<String> stack,
    required List<String> lookingFor,
    String? demoUrl,
    String? repoUrl,
  }) async {
    try {
      await _client.from('projects').update({
        'name': name,
        'description': description,
        'stack': stack,
        'looking_for': lookingFor,
        'demo_url': (demoUrl != null && demoUrl.isNotEmpty) ? demoUrl : null,
        'repo_url': (repoUrl != null && repoUrl.isNotEmpty) ? repoUrl : null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      await refresh();
      return null;
    } catch (e) {
      debugPrint('Update project failed: $e');
      return e.toString();
    }
  }

  /// Returns an error message, or null on success.
  Future<String?> deleteProject(String id) async {
    try {
      await _client.from('projects').delete().eq('id', id);
      _projects = _projects.where((p) => p.id != id).toList();
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Delete project failed: $e');
      return e.toString();
    }
  }
}
