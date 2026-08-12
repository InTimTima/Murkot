import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../models/user.dart';

enum PeopleSort { sharedSkills, login }

/// Directory of developers with filters (skill / city / status / query).
class PeopleService extends ChangeNotifier {
  PeopleService();

  final _client = Supabase.instance.client;

  List<User> _people = const [];
  bool _loading = false;
  String? _error;
  String? _skillFilter;
  String? _cityFilter;
  DevStatus? _statusFilter;
  String _searchQuery = '';
  PeopleSort _sort = PeopleSort.sharedSkills;
  final Map<String, int> _sharedSkills = {};

  bool get isLoading => _loading;
  String? get error => _error;
  String? get skillFilter => _skillFilter;
  String? get cityFilter => _cityFilter;
  DevStatus? get statusFilter => _statusFilter;
  String get searchQuery => _searchQuery;
  PeopleSort get sort => _sort;

  List<User> get people {
    final list = List<User>.from(_people);
    switch (_sort) {
      case PeopleSort.sharedSkills:
        list.sort((a, b) {
          final sa = _sharedSkills[a.id] ?? 0;
          final sb = _sharedSkills[b.id] ?? 0;
          final cmp = sb.compareTo(sa);
          if (cmp != 0) return cmp;
          return a.login.toLowerCase().compareTo(b.login.toLowerCase());
        });
      case PeopleSort.login:
        list.sort(
          (a, b) => a.login.toLowerCase().compareTo(b.login.toLowerCase()),
        );
    }
    return list;
  }

  int sharedSkillsFor(String userId) => _sharedSkills[userId] ?? 0;

  List<String> get availableSkills {
    final set = <String>{};
    for (final u in _people) {
      set.addAll(u.skills.where((s) => s.trim().isNotEmpty));
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<String> get availableCities {
    final set = <String>{};
    for (final u in _people) {
      final city = u.city?.trim();
      if (city != null && city.isNotEmpty) set.add(city);
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  bool get hasActiveFilters =>
      _skillFilter != null ||
      _cityFilter != null ||
      _statusFilter != null ||
      _searchQuery.trim().isNotEmpty;

  int get activeFilterCount {
    var n = 0;
    if (_skillFilter != null) n++;
    if (_cityFilter != null) n++;
    if (_statusFilter != null) n++;
    if (_searchQuery.trim().isNotEmpty) n++;
    return n;
  }

  void setSkillFilter(String? skill) {
    final next = skill?.trim();
    final normalized = (next == null || next.isEmpty) ? null : next;
    if (_skillFilter == normalized) return;
    _skillFilter = normalized;
    notifyListeners();
    refresh();
  }

  void setCityFilter(String? city) {
    final next = city?.trim();
    final normalized = (next == null || next.isEmpty) ? null : next;
    if (_cityFilter == normalized) return;
    _cityFilter = normalized;
    notifyListeners();
    refresh();
  }

  void setStatusFilter(DevStatus? status) {
    if (_statusFilter == status) return;
    _statusFilter = status;
    notifyListeners();
    refresh();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  /// Debounced-friendly: call after typing settles or on submit.
  void applySearchAndRefresh() {
    refresh();
  }

  void setSort(PeopleSort sort) {
    if (_sort == sort) return;
    _sort = sort;
    notifyListeners();
  }

  void clearFilters({bool reload = true}) {
    if (!hasActiveFilters && _sort == PeopleSort.sharedSkills) return;
    _skillFilter = null;
    _cityFilter = null;
    _statusFilter = null;
    _searchQuery = '';
    _sort = PeopleSort.sharedSkills;
    notifyListeners();
    if (reload) refresh();
  }

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final rows = await _client.rpc(
        'search_people',
        params: {
          'p_query': _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
          'p_skill': _skillFilter,
          'p_city': _cityFilter,
          'p_dev_status': _statusFilter?.dbValue,
          'p_limit': 60,
          'p_offset': 0,
        },
      );
      final list = <User>[];
      final shared = <String, int>{};
      if (rows is List) {
        for (final raw in rows) {
          final map = Map<String, dynamic>.from(raw as Map);
          final user = User.fromProfileRow(map);
          list.add(user);
          shared[user.id] = (map['shared_skills'] as num?)?.toInt() ?? 0;
        }
      }
      _people = list;
      _sharedSkills
        ..clear()
        ..addAll(shared);
      _error = null;
    } catch (e) {
      debugPrint('PeopleService.refresh failed: $e');
      _error = e.toString();
      _people = const [];
      _sharedSkills.clear();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
