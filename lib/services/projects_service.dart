import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/project.dart';
import 'public_profile_lookup.dart';

enum ProjectSort { newest, relevance }

/// Loads and mutates the project showcase.
class ProjectsService extends ChangeNotifier {
  ProjectsService({required String userId}) : _userId = userId;

  final String _userId;
  final _client = Supabase.instance.client;

  static const _authorSelect =
      '*, author:profiles!projects_author_id_fkey(id, login, status, avatar_emoji, avatar_url, is_bot, city, avatar_frame, nick_color, is_plus)';

  List<Project> _projects = const [];
  bool _loading = false;
  String? _error;
  String? _skillFilter;
  String? _roleFilter;
  String? _cityFilter;
  String _searchQuery = '';
  ProjectSort _sort = ProjectSort.newest;

  bool get isLoading => _loading;
  String? get error => _error;
  String? get skillFilter => _skillFilter;
  String? get roleFilter => _roleFilter;
  String? get cityFilter => _cityFilter;
  String get searchQuery => _searchQuery;
  ProjectSort get sort => _sort;

  /// Projects matching the current filters.
  List<Project> get projects {
    final skill = _skillFilter;
    final role = _roleFilter;
    final city = _cityFilter;
    final q = _searchQuery.trim().toLowerCase();

    Iterable<Project> base = _projects;
    if (skill != null) {
      base = base.where(
        (p) => p.stack.any((s) => s.toLowerCase() == skill.toLowerCase()),
      );
    }
    if (role != null) {
      base = base.where(
        (p) =>
            p.lookingFor.any((r) => r.toLowerCase() == role.toLowerCase()),
      );
    }
    if (city != null) {
      base = base.where(
        (p) => (p.author.city ?? '').toLowerCase() == city.toLowerCase(),
      );
    }
    if (q.isNotEmpty) {
      base = base.where((p) {
        if (p.name.toLowerCase().contains(q)) return true;
        if (p.description.toLowerCase().contains(q)) return true;
        if (p.stack.any((s) => s.toLowerCase().contains(q))) return true;
        if (p.lookingFor.any((r) => r.toLowerCase().contains(q))) return true;
        if ((p.author.city ?? '').toLowerCase().contains(q)) return true;
        if (p.author.login.toLowerCase().contains(q)) return true;
        return false;
      });
    }

    final list = base.toList();
    if (_sort == ProjectSort.relevance && q.isNotEmpty) {
      list.sort((a, b) {
        final cmp = _relevanceScore(b, q).compareTo(_relevanceScore(a, q));
        if (cmp != 0) return cmp;
        return b.createdAt.compareTo(a.createdAt);
      });
    }
    return list;
  }

  static int _relevanceScore(Project project, String q) {
    var score = 0;
    final name = project.name.toLowerCase();
    if (name == q) {
      score += 100;
    } else if (name.startsWith(q)) {
      score += 60;
    } else if (name.contains(q)) {
      score += 40;
    }
    if (project.stack.any((s) => s.toLowerCase() == q)) {
      score += 30;
    } else if (project.stack.any((s) => s.toLowerCase().contains(q))) {
      score += 15;
    }
    if (project.lookingFor.any((r) => r.toLowerCase().contains(q))) {
      score += 12;
    }
    if (project.description.toLowerCase().contains(q)) score += 10;
    if ((project.author.city ?? '').toLowerCase().contains(q)) score += 8;
    if (project.author.login.toLowerCase().contains(q)) score += 5;
    return score;
  }

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

  List<String> get availableRoles {
    final seen = <String, String>{};
    for (final project in _projects) {
      for (final role in project.lookingFor) {
        seen.putIfAbsent(role.toLowerCase(), () => role);
      }
    }
    final roles = seen.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return roles;
  }

  List<String> get availableCities {
    final seen = <String, String>{};
    for (final project in _projects) {
      final city = project.author.city;
      if (city == null || city.isEmpty) continue;
      seen.putIfAbsent(city.toLowerCase(), () => city);
    }
    final cities = seen.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return cities;
  }

  bool isMine(Project project) => project.authorId == _userId;

  void setSkillFilter(String? skill) {
    if (_skillFilter == skill) return;
    _skillFilter = skill;
    notifyListeners();
  }

  void setRoleFilter(String? role) {
    if (_roleFilter == role) return;
    _roleFilter = role;
    notifyListeners();
  }

  void setCityFilter(String? city) {
    if (_cityFilter == city) return;
    _cityFilter = city;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    final hasQuery = _searchQuery.trim().isNotEmpty;
    if (hasQuery && _sort == ProjectSort.newest) {
      _sort = ProjectSort.relevance;
    } else if (!hasQuery && _sort == ProjectSort.relevance) {
      _sort = ProjectSort.newest;
    }
    notifyListeners();
  }

  void setSort(ProjectSort sort) {
    if (_sort == sort) return;
    _sort = sort;
    notifyListeners();
  }

  bool get hasActiveFilters =>
      _skillFilter != null ||
      _roleFilter != null ||
      _cityFilter != null ||
      _searchQuery.trim().isNotEmpty;

  int get activeChipFilterCount {
    var n = 0;
    if (_skillFilter != null) n++;
    if (_roleFilter != null) n++;
    if (_cityFilter != null) n++;
    return n;
  }

  void clearFilters() {
    if (!hasActiveFilters && _sort == ProjectSort.newest) return;
    _skillFilter = null;
    _roleFilter = null;
    _cityFilter = null;
    _searchQuery = '';
    _sort = ProjectSort.newest;
    notifyListeners();
  }

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      try {
        final rows = await _client
            .from('projects')
            .select(_authorSelect)
            .order('created_at', ascending: false)
            .limit(100);

        _projects = (rows as List)
            .map((row) =>
                Project.fromRow(Map<String, dynamic>.from(row as Map)))
            .toList();
      } catch (e) {
        debugPrint('Projects embed failed: $e');
        final rows = await _client
            .from('projects')
            .select()
            .order('created_at', ascending: false)
            .limit(100);
        _projects = (rows as List)
            .map((row) =>
                Project.fromRow(Map<String, dynamic>.from(row as Map)))
            .toList();
      }
      _projects = await _hydrateAuthors(_projects);
    } catch (e) {
      debugPrint('Projects refresh failed: $e');
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> createProject({
    required String name,
    required String description,
    required List<String> stack,
    required List<String> lookingFor,
    String? demoUrl,
    String? repoUrl,
    String? avatarUrl,
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
        if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
      });
      await refresh();
      return null;
    } catch (e) {
      debugPrint('Create project failed: $e');
      return e.toString();
    }
  }

  Future<String?> updateProject({
    required String id,
    required String name,
    required String description,
    required List<String> stack,
    required List<String> lookingFor,
    String? demoUrl,
    String? repoUrl,
    String? avatarUrl,
  }) async {
    try {
      await _client.from('projects').update({
        'name': name,
        'description': description,
        'stack': stack,
        'looking_for': lookingFor,
        'demo_url': (demoUrl != null && demoUrl.isNotEmpty) ? demoUrl : null,
        'repo_url': (repoUrl != null && repoUrl.isNotEmpty) ? repoUrl : null,
        if (avatarUrl != null) 'avatar_url': avatarUrl.isEmpty ? null : avatarUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      await refresh();
      return null;
    } catch (e) {
      debugPrint('Update project failed: $e');
      return e.toString();
    }
  }

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

  Future<List<Project>> _hydrateAuthors(List<Project> projects) async {
    final missing = projects
        .where((p) => p.author.login == '?' || p.author.login.isEmpty)
        .map((p) => p.authorId)
        .toSet();
    if (missing.isEmpty) return projects;
    final previews = await loadPublicPreviews(missing);
    if (previews.isEmpty) return projects;
    return [
      for (final project in projects)
        previews.containsKey(project.authorId)
            ? Project(
                id: project.id,
                authorId: project.authorId,
                author: previews[project.authorId]!,
                name: project.name,
                description: project.description,
                stack: project.stack,
                lookingFor: project.lookingFor,
                createdAt: project.createdAt,
                demoUrl: project.demoUrl,
                repoUrl: project.repoUrl,
                avatarUrl: project.avatarUrl,
                imageUrls: project.imageUrls,
              )
            : project,
    ];
  }
}
