import 'package:equatable/equatable.dart';

/// Why a post was reported. The wire values are the API's own enum; the
/// labels are what the report sheet lists, in this order.
enum ReportReason {
  spam('SPAM', 'Spam'),
  harassment('HARASSMENT', 'Harassment or bullying'),
  hate('HATE', 'Hate speech'),
  violence('VIOLENCE', 'Violence or threats'),
  sexual('SEXUAL', 'Nudity or sexual content'),
  misinformation('MISINFORMATION', 'False information'),
  other('OTHER', 'Something else');

  const ReportReason(this.wire, this.label);

  final String wire;
  final String label;

  static ReportReason fromWire(String? value) =>
      ReportReason.values.firstWhere((r) => r.wire == value, orElse: () => ReportReason.other);
}

/// Where a report got to. A new one always starts [underReview] — a status
/// sent by the client is ignored — and only a moderator moves it on.
enum ReportStatus {
  underReview('UNDER_REVIEW', 'Under review'),

  /// A moderator hid the post. It is not deleted, and the moderation portal
  /// can put it back.
  actionTaken('ACTION_TAKEN', 'Post removed'),

  noViolation('NO_VIOLATION', 'No action taken');

  const ReportStatus(this.wire, this.label);

  final String wire;
  final String label;

  bool get isResolved => this != underReview;

  static ReportStatus fromWire(String? value) =>
      ReportStatus.values.firstWhere((s) => s.wire == value, orElse: () => ReportStatus.underReview);
}

/// What the reported post looked like **when the report was made**, frozen
/// server-side so the row stays readable after the post is hidden or
/// deleted. Not a live read of the post — by the time a report resolves,
/// the post it names may not exist any more.
class ReportedPostSnapshot extends Equatable {
  const ReportedPostSnapshot({this.authorName, this.excerpt});

  /// The author's full name, or their username when they have no full name.
  final String? authorName;

  /// The post's first 80 characters. Null for an image-only post.
  final String? excerpt;

  @override
  List<Object?> get props => [authorName, excerpt];
}

/// One row of `GET /v1/reports/me`, and what `POST /v1/posts/{id}/reports`
/// answers with. The reported post's author never learns who filed it.
class PostReportEntity extends Equatable {
  const PostReportEntity({
    required this.id,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.postId,
    this.resolvedAt,
    this.post,
  });

  final String id;

  /// Null once the post has been deleted — so never navigate off this
  /// without checking it.
  final String? postId;

  final ReportReason reason;
  final ReportStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  /// Null when the API sent no snapshot at all; see [ReportedPostSnapshot].
  final ReportedPostSnapshot? post;

  @override
  List<Object?> get props => [id, postId, reason, status, createdAt, resolvedAt, post];
}
