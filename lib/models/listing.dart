import 'user_preview.dart';

/// What kind of ad this is.
enum ListingType {
  lookingForTeam('looking_for_team'),
  lookingForMembers('looking_for_members');

  const ListingType(this.dbValue);

  final String dbValue;

  static ListingType fromDb(String value) => ListingType.values.firstWhere(
        (t) => t.dbValue == value,
        orElse: () => ListingType.lookingForTeam,
      );
}

/// How the work is compensated.
enum ListingCompensation {
  paid('paid'),
  equity('equity'),
  petProject('pet_project');

  const ListingCompensation(this.dbValue);

  final String dbValue;

  static ListingCompensation? fromDb(String? value) {
    for (final c in ListingCompensation.values) {
      if (c.dbValue == value) return c;
    }
    return null;
  }
}

class Listing {
  const Listing({
    required this.id,
    required this.authorId,
    required this.author,
    required this.type,
    required this.title,
    required this.description,
    required this.skills,
    required this.createdAt,
    this.compensation,
    this.isActive = true,
  });

  final String id;
  final String authorId;
  final UserPreview author;
  final ListingType type;
  final String title;
  final String description;
  final List<String> skills;
  final ListingCompensation? compensation;
  final bool isActive;
  final DateTime createdAt;

  /// Parses a row from `.from('listings').select('*, author:profiles(...)')`.
  factory Listing.fromRow(Map<String, dynamic> row) {
    final authorRow = row['author'];
    return Listing(
      id: row['id'] as String,
      authorId: row['author_id'] as String,
      author: authorRow is Map
          ? UserPreview.fromRow(Map<String, dynamic>.from(authorRow))
          : UserPreview(id: row['author_id'] as String, login: '?'),
      type: ListingType.fromDb(row['type'] as String),
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      skills: switch (row['skills']) {
        final List list => list.map((e) => e.toString()).toList(),
        _ => const <String>[],
      },
      compensation: ListingCompensation.fromDb(row['compensation'] as String?),
      isActive: row['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }
}

enum ListingResponseStatus {
  pending('pending'),
  inChat('in_chat'),
  accepted('accepted'),
  rejected('rejected'),
  withdrawn('withdrawn');

  const ListingResponseStatus(this.dbValue);
  final String dbValue;

  static ListingResponseStatus fromDb(String? value) =>
      ListingResponseStatus.values.firstWhere(
        (s) => s.dbValue == value,
        orElse: () => ListingResponseStatus.inChat,
      );
}

class ListingResponse {
  const ListingResponse({
    required this.id,
    required this.listingId,
    required this.responderId,
    required this.status,
    required this.createdAt,
    this.conversationId,
    this.note = '',
    this.responderLogin,
    this.responderEmoji,
  });

  final String id;
  final String listingId;
  final String responderId;
  final ListingResponseStatus status;
  final String? conversationId;
  final String note;
  final DateTime createdAt;
  final String? responderLogin;
  final String? responderEmoji;

  factory ListingResponse.fromRow(Map<String, dynamic> row) {
    final responder = row['responder'];
    return ListingResponse(
      id: row['id'] as String,
      listingId: row['listing_id'] as String,
      responderId: row['responder_id'] as String,
      status: ListingResponseStatus.fromDb(row['status'] as String?),
      conversationId: row['conversation_id'] as String?,
      note: row['note'] as String? ?? '',
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '')
              ?.toLocal() ??
          DateTime.now(),
      responderLogin: responder is Map
          ? responder['login'] as String?
          : null,
      responderEmoji: responder is Map
          ? responder['avatar_emoji'] as String?
          : null,
    );
  }
}
