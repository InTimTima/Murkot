import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/listing.dart';
import 'analytics_service.dart';

/// Loads and mutates the listings board ("looking for team" ads).
class ListingsService extends ChangeNotifier {
  ListingsService({required String userId}) : _userId = userId;

  final String _userId;
  final _client = Supabase.instance.client;

  static const _authorSelect =
      '*, author:profiles(id, login, status, avatar_emoji, avatar_url, is_bot)';

  List<Listing> _listings = const [];
  final Set<String> _hiddenIds = {};
  bool _loading = false;
  String? _error;
  ListingType? _typeFilter;
  String? _skillFilter;

  bool get isLoading => _loading;
  String? get error => _error;
  ListingType? get typeFilter => _typeFilter;
  String? get skillFilter => _skillFilter;

  /// Listings matching the current filters, newest first (minus hidden).
  List<Listing> get listings {
    final skill = _skillFilter;
    Iterable<Listing> base = _listings.where((l) => !_hiddenIds.contains(l.id));
    if (skill != null) {
      base = base.where((l) =>
          l.skills.any((s) => s.toLowerCase() == skill.toLowerCase()));
    }
    return base.toList();
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

  bool get hasActiveFilters => _typeFilter != null || _skillFilter != null;

  void clearFilters() {
    if (_typeFilter == null && _skillFilter == null) return;
    _typeFilter = null;
    _skillFilter = null;
    notifyListeners();
    refresh();
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
