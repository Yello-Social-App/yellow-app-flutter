import '../../domain/entities/community_entity.dart';
import '../../domain/entities/community_post_entity.dart';
import 'community_model.dart';

/// JSON mapping for the backend's `CommunityPost` schema.
class CommunityPostModel extends CommunityPostEntity {
  const CommunityPostModel({
    required super.id,
    required super.community,
    required super.authorId,
    required super.authorUsername,
    super.authorFullName,
    super.authorAvatarUrl,
    required super.title,
    required super.body,
    required super.tag,
    super.score,
    super.reactionCounts,
    super.viewerReaction,
    super.commentCount,
    required super.createdAt,
    super.viewerVote,
    super.isOwner,
  });

  factory CommunityPostModel.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>? ?? const {};
    final community = json['community'] as Map<String, dynamic>?;

    return CommunityPostModel(
      id: json['id'] as String,
      community: community == null
          ? const CommunitySummaryEntity(slug: '', name: '', emoji: '💬')
          : CommunitySummaryModel.fromJson(community),
      authorId: author['id'] as String? ?? '',
      authorUsername: author['username'] as String? ?? 'unknown',
      authorFullName: author['fullName'] as String?,
      authorAvatarUrl: author['avatarUrl'] as String?,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      // Same shape as `Post.reactionCounts`: per-type counts *plus* a sibling
      // `total` key in the same object. Dropped here rather than stored as if
      // it were a 7th reaction type — keeping it would make
      // `reactionTotal` (which sums every value) double-count.
      reactionCounts: {
        for (final entry in (json['reactionCounts'] as Map<String, dynamic>? ?? const {}).entries)
          if (entry.key != 'total') entry.key: (entry.value as num).toInt(),
      },
      viewerReaction: json['viewerReaction'] as String?,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      viewerVote: CommunityVote.fromWire((json['viewerVote'] as num?)?.toInt()),
      isOwner: json['isOwner'] as bool? ?? false,
    );
  }
}

/// `CommunityPostVote` — the response to `PUT /community-posts/{id}/vote`.
class CommunityPostVoteResultModel extends CommunityPostVoteResult {
  const CommunityPostVoteResultModel({
    required super.id,
    required super.score,
    required super.viewerVote,
  });

  factory CommunityPostVoteResultModel.fromJson(Map<String, dynamic> json) =>
      CommunityPostVoteResultModel(
        id: json['id'] as String? ?? '',
        score: (json['score'] as num?)?.toInt() ?? 0,
        viewerVote: CommunityVote.fromWire((json['viewerVote'] as num?)?.toInt()),
      );
}
