import '../../domain/entities/post_report_entity.dart';

/// Parses the API's `PostReport` — what `POST /v1/posts/{id}/reports`
/// answers with and what fills `GET /v1/reports/me`:
///
/// ```json
/// { "id": "5e1d9a0c-…", "postId": "8f3c2a1e-…", "reason": "SPAM",
///   "status": "UNDER_REVIEW", "createdAt": "2026-09-22T10:16:00Z",
///   "resolvedAt": null,
///   "post": { "authorName": "Marcus Rell", "excerpt": "Crypto giveaway!!…" } }
/// ```
///
/// `postId` and `post` are both nullable on purpose: the post can be
/// deleted after the report is filed, which nulls the first and leaves the
/// second as the only readable record of what was reported.
class PostReportModel extends PostReportEntity {
  const PostReportModel({
    required super.id,
    required super.reason,
    required super.status,
    required super.createdAt,
    super.postId,
    super.resolvedAt,
    super.post,
  });

  factory PostReportModel.fromJson(Map<String, dynamic> json) {
    final post = json['post'];
    final resolvedAt = json['resolvedAt'] as String?;
    return PostReportModel(
      id: json['id'] as String? ?? '',
      postId: json['postId'] as String?,
      reason: ReportReason.fromWire(json['reason'] as String?),
      status: ReportStatus.fromWire(json['status'] as String?),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      resolvedAt: resolvedAt == null ? null : DateTime.tryParse(resolvedAt),
      post: post is Map<String, dynamic>
          ? ReportedPostSnapshot(
              authorName: post['authorName'] as String?,
              excerpt: post['excerpt'] as String?,
            )
          : null,
    );
  }
}
