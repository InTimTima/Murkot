import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/listing.dart';
import 'analytics_service.dart';

enum ListingSort { newest, relevance }

/// Loads and mutates the listings board ("looking for team" ads).
class ListingsService extends ChangeNotifier {
  ListingsService({required String userId}) : _userId = userId;

  final String _userId;
  final _client = Supabase.instance.client;

  // Disambiguate after hidden_listings created a second listings↔profiles path.
  static const _authorSelect =
      '*, author:profiles!listings_author_id_fkey(id, login, status, avatar_emoji, avatar_url, is_bot, city)';

  List<Listing> _listings = const [];
  final Set<String> _hiddenIds = {};
  bool _loading = false;
  String? _error;
  ListingType? _typeFilter;
  String? _skillFilter;
  String? _cityFilter;
  ListingCompensation? _compensationFilter;
  String _searchQuery = '';
  ListingSort _sort = ListingSort.newest;

  bool get isLoading => _loading;
  String? get error => _error;
  ListingType? get typeFilter => _typeFilter;
  String? get skillFilter => _skillFilter;
  String? get cityFilter => _cityFilter;
  ListingCompensation? get compensationFilter => _compensationFilter;
  String get searchQuery => _searchQuery;
  ListingSort get sort => _sort;

  /// Listings matching the current filters (minus hidden).
  List<Listing> get listings {
    final skill = _skillFilter;
    final city = _cityFilter;
    final compensation = _compensationFilter;
    final q = _searchQuery.trim().toLowerCase();

    Iterable<Listing> base = _listings.where((l) => !_hiddenIds.contains(l.id));
    if (skill != null) {
      base = base.where(
        (l) => l.skills.any((s) => s.toLowerCase() == skill.toLowerCase()),
      );
    }
    if (city != null) {
      base = base.where(
        (l) => (l.author.city ?? '').toLowerCase() == city.toLowerCase(),
      );
    }
    if (compensation != null) {
      base = base.where((l) => l.compensation == compensation);
    }
    if (q.isNotEmpty) {
      base = base.where((l) {
        if (l.title.toLowerCase().contains(q)) return true;
        if (l.description.toLowerCase().contains(q)) return true;
        if (l.skills.any((s) => s.toLowerCase().contains(q))) return true;
        if ((l.author.city ?? '').toLowerCase().contains(q)) return true;
        if (l.author.login.toLowerCase().contains(q)) return true;
        return false;
      });
    }

    final list = base.toList();
    if (_sort == ListingSort.relevance && q.isNotEmpty) {
      list.sort((a, b) {
        final scoreCmp = _relevanceScore(b, q).compareTo(_relevanceScore(a, q));
        if (scoreCmp != 0) return scoreCmp;
        return b.createdAt.compareTo(a.createdAt);
      });
    }
    return list;
  }

  static int _relevanceScore(Listing listing, String q) {
    var score = 0;
    final title = listing.title.toLowerCase();
    final desc = listing.description.toLowerCase();
    if (title == q) {
      score += 100;
    } else if (title.startsWith(q)) {
      score += 60;
    } else if (title.contains(q)) {
      score += 40;
    }
    if (listing.skills.any((s) => s.toLowerCase() == q)) {
      score += 30;
    } else if (listing.skills.any((s) => s.toLowerCase().contains(q))) {
      score += 15;
    }
    if (desc.contains(q)) score += 10;
    if ((listing.author.city ?? '').toLowerCase().contains(q)) score += 8;
    if (listing.author.login.toLowerCase().contains(q)) score += 5;
    return score;
  }

  /// All distinct skill tags across loaded listings (for filter chips).
  List<String> get availableSkills {
    final seen = <String, String>{};
    for (final listing in _listings) {
      for (final skill in listing.skills) {
        seen.putIfAbsent(skill.toLowerCase(), () => skill);
      }
    }
    final tags = seen.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return tags;
  }

  /// Distinct author cities from loaded listings.
  List<String> get availableCities {
    final seen = <String, String>{};
    for (final listing in _listings) {
      final city = listing.author.city;
      if (city == null || city.isEmpty) continue;
      seen.putIfAbsent(city.toLowerCase(), () => city);
    }
    final cities = seen.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return cities;
  }

  bool isMine(Listing listing) => listing.authorId == _userId;

  void setTypeFilter(ListingType? type) {
    if (_typeFilter == type) return;
    _typeFilter = type;
    notifyListeners();
    refresh();
  }

  void setSkillFilter(String? skill) {
    if (_skillFilter == skill) return;
    _skillFilter = skill;
    notifyListeners();
  }

  void setCityFilter(String? city) {
    if (_cityFilter == city) return;
    _cityFilter = city;
    notifyListeners();
  }

  void setCompensationFilter(ListingCompensation? compensation) {
    if (_compensationFilter == compensation) return;
    _compensationFilter = compensation;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    final hasQuery = _searchQuery.trim().isNotEmpty;
    if (hasQuery && _sort == ListingSort.newest) {
      _sort = ListingSort.relevance;
    } else if (!hasQuery && _sort == ListingSort.relevance) {
      _sort = ListingSort.newest;
    }
    notifyListeners();
  }

  void setSort(ListingSort sort) {
    if (_sort == sort) return;
    _sort = sort;
    notifyListeners();
  }

  bool get hasActiveFilters =>
      _typeFilter != null ||
      _skillFilter != null ||
      _cityFilter != null ||
      _compensationFilter != null ||
      _searchQuery.trim().isNotEmpty;

  /// Chip filters only (type / city / skill / compensation) — for badge.
  int get activeChipFilterCount {
    var n = 0;
    if (_typeFilter != null) n++;
    if (_skillFilter != null) n++;
    if (_cityFilter != null) n++;
    if (_compensationFilter != null) n++;
    return n;
  }

  void clearFilters() {
    final hadType = _typeFilter != null;
    if (!hasActiveFilters && _sort == ListingSort.newest) return;
    _typeFilter = null;
    _skillFilter = null;
    _cityFilter = null;
    _compensationFilter = null;
    _searchQuery = '';
    _sort = ListingSort.newest;
    notifyListeners();
    if (hadType) {
      refresh();
    }
  }

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      var query =
          _client.from('listings').select(_authorSelect).eq('is_active', true);
      final type = _typeFilter;
      if (type != null) {
        query = query.eq('type', type.dbValue);
      }
      final rows = await query.order('created_at', ascending: false).limit(100);

      _listings = (rows as List)
          .map((row) => Listing.fromRow(Map<String, dynamic>.from(row as Map)))
          .toList();

      try {
        final hidden = await _client
            .from('hidden_listings')
            .select('listing_id')
            .eq('user_id', _userId);
        _hiddenIds
          ..clear()
          ..addAll(
            (hidden as List).map((r) => (r as Map)['listing_id'] as String),
          );
      } catch (e) {
        debugPrint('Hidden listings load failed: $e');
      }
    } catch (e) {
      debugPrint('Listings refresh failed: $e');
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Returns an error message, or null on success.
  Future<String?> createListing({
    required ListingType type,
    required String title,
    required String description,
    required List<String> skills,
    ListingCompensation? compensation,
  }) async {
    try {
      await _client.from('listings').insert({
        'author_id': _userId,
        'type': type.dbValue,
        'title': title,
        'description': description,
        'skills': skills,
        'compensation': compensation?.dbValue,
      });
      await AnalyticsService.instance.track('listing_create', {
        'type': type.dbValue,
      });
      await refresh();
      return null;
    } catch (e) {
      debugPrint('Create listing failed: $e');
      return e.toString();
    }
  }

  /// Returns an error message, or null on success.
  Future<String?> updateListing({
    required String id,
    required ListingType type,
    required String title,
    required String description,
    required List<String> skills,
    ListingCompensation? compensation,
  }) async {
    try {
      await _client.from('listings').update({
        'type': type.dbValue,
        'title': title,
        'description': description,
        'skills': skills,
        'compensation': compensation?.dbValue,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      await refresh();
      return null;
    } catch (e) {
      debugPrint('Update listing failed: $e');
      return e.toString();
    }
  }

  /// Hide a listing for the current user only.
  Future<String?> hideListing(String id) async {
    try {
      await _client.from('hidden_listings').upsert({
        'user_id': _userId,
        'listing_id': id,
      });
      _hiddenIds.add(id);
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Hide listing failed: $e');
      return e.toString();
    }
  }

  /// Returns an error message, or null on success.
  Future<String?> deleteListing(String id) async {
    try {
      await _client.from('listings').delete().eq('id', id);
      _listings = _listings.where((l) => l.id != id).toList();
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Delete listing failed: $e');
      return e.toString();
    }
  }
}
