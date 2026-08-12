import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/match_candidate.dart';
import 'analytics_service.dart';

/// Swipe-based team-building matching.
class MatchService extends ChangeNotifier {
  MatchService();

  final _client = Supabase.instance.client;

  List<MatchCandidate> _feed = const [];
  List<MatchCandidate> _matches = const [];
  bool _loadingFeed = false;
  bool _loadingMatches = false;
  bool _swiping = false;
  String? _feedError;
  String? _matchesError;

  List<MatchCandidate> get feed => _feed;
  List<MatchCandidate> get matches => _matches;
  bool get isLoadingFeed => _loadingFeed;
  bool get isLoadingMatches => _loadingMatches;
  bool get isSwiping => _swiping;
  String? get feedError => _feedError;
  String? get matchesError => _matchesError;
  MatchCandidate? get current => _feed.isEmpty ? null : _feed.first;

  Future<void> refreshFeed() async {
    _loadingFeed = true;
    _feedError = null;
    notifyListeners();

    try {
      final rows = await _client.rpc('get_match_feed', params: {'p_limit': 40});
      _feed = (rows as List)
          .map((row) =>
              MatchCandidate.fromRow(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e) {
      debugPrint('Match feed failed: $e');
      _feedError = e.toString();
    } finally {
      _loadingFeed = false;
      notifyListeners();
    }
  }

  Future<void> refreshMatches() async {
    _loadingMatches = true;
    _matchesError = null;
    notifyListeners();

    try {
      final rows = await _client.rpc('get_my_matches');
      _matches = (rows as List)
          .map((row) =>
              MatchCandidate.fromRow(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e) {
      debugPrint('Matches load failed: $e');
      _matchesError = e.toString();
    } finally {
      _loadingMatches = false;
      notifyListeners();
    }
  }

  /// Records a like/pass for [candidate]. Returns true on mutual match.
  Future<bool?> swipe({
    required MatchCandidate candidate,
    required bool liked,
  }) async {
    if (_swiping) return null;

    _swiping = true;
    notifyListeners();

    try {
      final rows = await _client.rpc(
        'swipe_match',
        params: {
          'p_target_id': candidate.user.id,
          'p_liked': liked,
        },
      );
      final isMatch = rows is List &&
          rows.isNotEmpty &&
          (Map<String, dynamic>.from(rows.first as Map)['is_match'] == true);

      _feed =
          _feed.where((c) => c.user.id != candidate.user.id).toList(growable: false);
      if (isMatch) {
        await refreshMatches();
        await AnalyticsService.instance.track('match_mutual', {
          'target': candidate.user.login,
        });
      } else {
        await AnalyticsService.instance.track(
          liked ? 'match_like' : 'match_pass',
          {'target': candidate.user.login},
        );
      }
      return isMatch;
    } catch (e) {
      debugPrint('Swipe failed: $e');
      rethrow;
    } finally {
      _swiping = false;
      notifyListeners();
    }
  }

  /// Drops blocked users from the local feed and records a pass on the server
  /// so they do not reappear on the next refresh.
  Future<void> skipBlockedLogins(Iterable<String> blockedLogins) async {
    final blocked = blockedLogins.map((e) => e.toLowerCase()).toSet();
    if (blocked.isEmpty || _feed.isEmpty) return;

    final toSkip = _feed
        .where((c) => blocked.contains(c.user.login.toLowerCase()))
        .toList(growable: false);
    if (toSkip.isEmpty) return;

    final skipIds = toSkip.map((c) => c.user.id).toSet();
    _feed =
        _feed.where((c) => !skipIds.contains(c.user.id)).toList(growable: false);
    notifyListeners();

    for (final candidate in toSkip) {
      try {
        await _client.rpc(
          'swipe_match',
          params: {
            'p_target_id': candidate.user.id,
            'p_liked': false,
          },
        );
      } catch (e) {
        debugPrint('Skip blocked match failed: $e');
      }
    }
  }
}
