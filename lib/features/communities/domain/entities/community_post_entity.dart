import 'package:equatable/equatable.dart';

import '../../../feed/domain/entities/post_entity.dart' show ReactionType;
import 'community_entity.dart';

/// Field caps from `CreateCommunityPostRequest` — enforced at the keyboard as
/// well as server-side, so over-long input is stopped rather than silently
/// truncated on the way out.
const int kCommunityPostTitleMaxChars = 200;
const int kCommunityPostBodyMaxChars = 5000;

/// The viewer's vote on a community post. The wire value is an **integer**
/// (`-1 | 0 | 1`), and `PUT /community-posts/{id}/vote` takes it as an
/// absolute value rather than a delta — so clearing a vote means sending
/// [CommunityVote.none]'s `0`, not re-sending the same direction.
enum CommunityVote {
  down(-1),
  none(0),
  up(1);

  const CommunityVote(this.wireValue);

  final int wireValue;

  static CommunityVote fromWire(Object? value) => switch (value) {
    -1 => CommunityVote.down,
    1 => CommunityVote.up,
    // Anything else — including a 0, a null, or a value a newer backend
    // introduces — reads as "no vote from me", which is the safe default for
    // a control that would otherwise render as already-voted.
    _ => CommunityVote.none,
  };

  /// The value to send when this button is tapped while [current] is active:
  /// tapping your own vote again clears it, which is what every threaded
  /// forum does and what the absolute-value contract makes possible.
  CommunityVote toggledFrom(CommunityVote current) => current == this ? CommunityVote.none : this;
}

/// `sort` for both community post lists (`/community-posts` and
/// `/communities/{slug}/posts`). `hot` is the server default.
enum CommunityPostSort {
  hot,
  /// `new` on the wire — spelled `recent` here because `new` is a Dart
  /// reserved word and cannot be an enum constant.
  recent,
  top;

  String get wireValue => switch (this) {
    CommunityPostSort.hot => 'hot',
    CommunityPostSort.recent => 'new',
    CommunityPostSort.top => 'top',
  };

  String get label => switch (this) {
    CommunityPostSort.hot => 'Hot',
    CommunityPostSort.recent => 'New',
    CommunityPostSort.top => 'Top',
  };
}

/// `scope` for `GET /community-posts` — the whole network, or only the
/// communities the viewer has joined. `all` is the server default.
enum CommunityFeedScope {
  all,
  joined;

  String get wireValue => switch (this) {
    CommunityFeedScope.all => 'all',
    CommunityFeedScope.joined => 'joined',
  };

  String get label => switch (this) {
    CommunityFeedScope.all => 'Everywhere',
    CommunityFeedScope.joined => 'My communities',
  };
}

/// A thread in a community — the backend's `CommunityPost`.
///
/// Related to but deliberately *not* a [PostEntity]: a community post has a
/// title and a flair tag, carries a score and a vote, has no images or
/// visibility, and lives on its own endpoints. Trying to reuse `PostEntity`
/// here would mean a pile of always-null fields on both sides.
///
/// It carries *both* a vote score and the six-way reaction set: voting orders
/// the list (`sort=hot|top`), reactions are the same social signal they are
/// on a feed post. The two are independent server-side.
class CommunityPostEntity extends Equatable {
  const CommunityPostEntity({
    required this.id,
    required this.community,
    required this.authorId,
    required this.authorUsername,
    this.authorFullName,
    this.authorAvatarUrl,
    required this.title,
    required this.body,
    required this.tag,
    this.score = 0,
    this.reactionCounts = const {},
    this.viewerReaction,
    this.commentCount = 0,
    required this.createdAt,
    this.viewerVote = CommunityVote.none,
    this.isOwner = false,
  });

  final String id;
  final CommunitySummaryEntity community;
  final String authorId;
  final String authorUsername;
  final String? authorFullName;
  final String? authorAvatarUrl;
  final String title;

  /// Markdown-free plain body. Nullable on the wire for a link/title-only
  /// thread; normalized to `''` here so the UI never null-checks it.
  final String body;

  /// One of the parent community's `tags`.
  final String tag;

  /// Net vote score (upvotes minus downvotes), server-computed.
  final int score;

  /// Reaction-type name (`LIKE`, `LOVE`, …) to count. As on `Post`, the wire
  /// map carries a sibling `total` key that is *not* a reaction type — see
  /// `CommunityPostModel` for where it is stripped.
  final Map<String, int> reactionCounts;
  final String? viewerReaction;
  final int commentCount;
  final DateTime createdAt;
  final CommunityVote viewerVote;
  final bool isOwner;

  String get authorDisplayName =>
      (authorFullName == null || authorFullName!.isEmpty) ? authorUsername : authorFullName!;

  bool get hasBody => body.trim().isNotEmpty;

  ReactionType? get viewerReactionType => ReactionType.fromWire(viewerReaction);

  int get reactionTotal => reactionCounts.values.fold(0, (a, b) => a + b);

  CommunityPostEntity copyWith({
    int? score,
    CommunityVote? viewerVote,
    Map<String, int>? reactionCounts,
    Object? viewerReaction = _unset,
    int? commentCount,
  }) {
    return CommunityPostEntity(
      id: id,
      community: community,
      authorId: authorId,
      authorUsername: authorUsername,
      authorFullName: authorFullName,
      authorAvatarUrl: authorAvatarUrl,
      title: title,
      body: body,
      tag: tag,
      score: score ?? this.score,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      viewerReaction: identical(viewerReaction, _unset) ? this.viewerReaction : viewerReaction as String?,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt,
      viewerVote: viewerVote ?? this.viewerVote,
      isOwner: isOwner,
    );
  }

  @override
  List<Object?> get props => [id, title, body, score, viewerVote, reactionCounts, viewerReaction, commentCount];
}

/// `PUT /community-posts/{id}/vote`'s response (`CommunityPostVote`) — just
/// enough to update the row in place without re-fetching the list.
class CommunityPostVoteResult extends Equatable {
  const CommunityPostVoteResult({required this.id, required this.score, required this.viewerVote});

  final String id;
  final int score;
  final CommunityVote viewerVote;

  @override
  List<Object?> get props => [id, score, viewerVote];
}

const Object _unset = Object();
