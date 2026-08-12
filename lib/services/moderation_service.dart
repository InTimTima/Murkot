import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContentReport {
  const ContentReport({
    required this.id,
    required this.reporterId,
    required this.reporterLogin,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
    this.resolutionNote = '',
  });

  final String id;
  final String reporterId;
  final String reporterLogin;
  final String targetType;
  final String targetId;
  final String reason;
  final String status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String resolutionNote;

  factory ContentReport.fromRow(Map<String, dynamic> row) {
    return ContentReport(
      id: row['id'] as String,
      reporterId: row['reporter_id'] as String,
      reporterLogin: row['reporter_login'] as String? ?? '?',
      targetType: row['target_type'] as String,
      targetId: row['target_id'] as String,
      reason: row['reason'] as String? ?? '',
      status: row['status'] as String? ?? 'open',
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      resolvedAt: DateTime.tryParse(row['resolved_at'] as String? ?? ''),
      resolutionNote: row['resolution_note'] as String? ?? '',
    );
  }
}

class ModerationService extends ChangeNotifier {
  final _client = Supabase.instance.client;

  bool? _isModerator;
  bool _loading = false;
  String? _error;
  String _statusFilter = 'open';
  List<ContentReport> _reports = const [];

  bool? get isModerator => _isModerator;
  bool get isLoading => _loading;
  String? get error => _error;
  String get statusFilter => _statusFilter;
  List<ContentReport> get reports => _reports;

  Future<bool> checkModerator() async {
    try {
      final result = await _client.rpc('is_app_moderator');
      _isModerator = result == true;
    } catch (e) {
      debugPrint('is_app_moderator failed: $e');
      _isModerator = false;
    }
    notifyListeners();
    return _isModerator ?? false;
  }

  Future<void> refresh() async {
    if (_isModerator != true) {
      final ok = await checkModerator();
      if (!ok) return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final rows = await _client.rpc(
        'list_content_reports',
        params: {
          'p_status': _statusFilter,
          'p_limit': 50,
        },
      );
      _reports = (rows as List)
          .map((r) => ContentReport.fromRow(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      debugPrint('list_content_reports failed: $e');
      _error = e.toString();
      _reports = const [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setStatusFilter(String status) {
    if (_statusFilter == status) return;
    _statusFilter = status;
    notifyListeners();
    refresh();
  }

  Future<String?> resolveReport({
    required String reportId,
    required String status,
    String note = '',
  }) async {
    try {
      await _client.rpc(
        'resolve_content_report',
        params: {
          'p_report_id': reportId,
          'p_status': status,
          'p_note': note,
        },
      );
      await refresh();
      return null;
    } catch (e) {
      debugPrint('resolve_content_report failed: $e');
      return e.toString();
    }
  }

  Future<String?> deactivateListing(String listingId) async {
    try {
      await _client.rpc(
        'moderator_deactivate_listing',
        params: {'p_listing_id': listingId},
      );
      return null;
    } catch (e) {
      debugPrint('moderator_deactivate_listing failed: $e');
      return e.toString();
    }
  }
}
