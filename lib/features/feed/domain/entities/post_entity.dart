import 'package:equatable/equatable.dart';

/// The backend's 6 reaction types (`ReactionType` enum on
/// `ReactionRequest`/`ReactionSummaryResponse`) — `POST /reactions/{targetType}/{targetId}`
/// takes one of these as its optional `type` body field (omitted means
/// `LIKE`); the server decides add/change/remove from the viewer's current
/// reaction. Rendered as emoji rather than icon assets so no new art is
/// needed for a feature with no mockup reference (the design source only
/// ever drew a single heart/LIKE).
enum ReactionType {
  like,
  love,
  haha,
  wow,
  sad,
  angry;

  String get wireValue => switch (this) {
    ReactionType.like => 'LIKE',
    ReactionType.love => 'LOVE',
    ReactionType.haha => 'HAHA',
    ReactionType.wow => 'WOW',
    ReactionType.sad => 'SAD',
    ReactionType.angry => 'ANGRY',
  };

  /// The glyph this app draws for each type. A *display* choice, not a wire
  /// one: `LOVE` deliberately renders as 🖕 rather than ❤️ (asked for
  /// 2026-09-25, see ADR-031) — the backend enum is closed at six values, so
  /// a 🖕 tile has to borrow one of them, and `LOVE` is the one this app's
  /// quick-tap heart does *not* already stand for. It still travels as
  /// `LOVE` on the wire and counts as `LOVE` in the breakdown, so a client
  /// that hasn't made the same swap shows those reactions as ❤️.
  String get emoji => switch (this) {
    ReactionType.like => '👍',
    ReactionType.love => '🖕',
    ReactionType.haha => '😆',
    ReactionType.wow => '😮',
    ReactionType.sad => '😢',
    ReactionType.angry => '😠',
  };

  static ReactionType? fromWire(String? value) => switch (value) {
    'LIKE' => ReactionType.like,
    'LOVE' => ReactionType.love,
    'HAHA' => ReactionType.haha,
    'WOW' => ReactionType.wow,
    'SAD' => ReactionType.sad,
    'ANGRY' => ReactionType.angry,
    _ => null,
  };
}

/// The three things a reaction can be attached to — the `{targetType}` path
/// segment of `/reactions/{targetType}/{targetId}` (the backend's
/// `TargetType` enum). Previously spelled as bare `'POST'` / `'COMMENT'`
/// string literals at each call site, which is how `COMMUNITY_POST` could be
/// added server-side without anything here noticing.
enum ReactionTargetType {
  post,
  comment,
  communityPost;

  String get wireValue => switch (this) {
    ReactionTargetType.post => 'POST',
    ReactionTargetType.comment => 'COMMENT',
    ReactionTargetType.communityPost => 'COMMUNITY_POST',
  };

  static ReactionTargetType? fromWire(String? value) => switch (value) {
    'POST' => ReactionTargetType.post,
    'COMMENT' => ReactionTargetType.comment,
    'COMMUNITY_POST' => ReactionTargetType.communityPost,
    _ => null,
  };
}

/// Mirrors the backend's `visibility` enum on `PostResponse` /
/// `UpdatePostRequest` (`PUBLIC | FRIENDS | PRIVATE`) — the real-data
/// equivalent of the mockup's Public/Circle/Close audience picker.
enum PostVisibility {
  public,
  friends,
  private;

  String get wireValue => switch (this) {
    PostVisibility.public => 'PUBLIC',
    PostVisibility.friends => 'FRIENDS',
    PostVisibility.private => 'PRIVATE',
  };

  static PostVisibility fromWire(String? value) => switch (value) {
    'FRIENDS' => PostVisibility.friends,
    'PRIVATE' => PostVisibility.private,
    _ => PostVisibility.public,
  };
}

/// A single feed item, shaped directly after the backend's `PostResponse`
/// (`GET /api/v1/feed`, `GET /api/v1/posts/{id}`) — see
/// `data/models/post_model.dart` for the JSON mapping. Two fields have no
/// backend counterpart and are filled in locally rather than invented on
/// the wire:
/// - [savedByMe] — there's no bookmark endpoint; see `BookmarksRepository`.
/// - [repostedByMe] — `POST /posts/{id}/repost` has no paired "un-repost"
///   endpoint and no `repostedByMe`/`repostId` field exists on the wire
///   either (checked against a fresh `/v3/api-docs`), so this is filled in
///   locally by whichever cubit is showing the post: either a repost/cancel
///   made *this session* (kept in-memory, see e.g. `FeedCubit.toggleRepost`'s
///   doc), or one made in an *earlier* session, recovered at load time by
///   cross-referencing the viewer's own posts for an existing repost of this
///   one (see `FeedCubit._seedMyRepostIds`'s doc) — without that recovery
///   step this field silently forgot every repost on a cold app restart,
///   letting the same post be reposted twice.
/// - `viewerReaction`/`reactionCounts` drive [likedByMe]/[likeCount] (the
///   mockup's single heart maps onto the backend's `LIKE` reaction type)
///   and, for the full 6-type picker, [viewerReactionType]/[reactionTotal].
class PostEntity extends Equatable {
  const PostEntity({
    required this.id,
    required this.authorId,
    required this.authorUsername,
    this.authorAvatarUrl,
    this.authorFullName,
    required this.createdAt,
    required this.content,
    this.images = const [],
    this.visibility = PostVisibility.public,
    this.isOwner = false,
    this.commentCount = 0,
    this.repostCount = 0,
    this.reactionCounts = const {},
    this.viewerReaction,
    this.shareUrl,
    this.originalPost,
    this.savedByMe = false,
    this.repostedByMe = false,
  });

  final String id;
  final String authorId;
  final String authorUsername;
  final String? authorAvatarUrl;

  /// Display name — `AuthorSummary.fullName` on the wire. Nullable because
  /// the backend doesn't mark it required; prefer this over
  /// [authorUsername] wherever it's present.
  final String? authorFullName;
  final DateTime createdAt;
  final String content;

  /// One entry per image, in `position` order. `id` is what
  /// `removeImageIds` on `PUT /posts/{id}` takes to drop one on edit.
  final List<({String id, String url})> images;

  /// Bare URLs, derived from [images] — the shape every existing image
  /// widget (`PostImageCarousel` etc.) already renders from.
  List<String> get imageUrls => images.map((i) => i.url).toList();
  final PostVisibility visibility;

  /// The caller wrote this post — `PostResponse.isOwner`, computed
  /// server-side (always `false` without a token). Drives edit/delete
  /// controls; unlike [authorId] comparisons done elsewhere, this doesn't
  /// need a separate `/users/me` call to be trustworthy.
  final bool isOwner;
  final int commentCount;
  final int repostCount;

  /// Reaction-type name (`LIKE`, `LOVE`, `HAHA`, `WOW`, `SAD`, `ANGRY`) to
  /// count, straight from `PostResponse.reactionCounts`.
  final Map<String, int> reactionCounts;

  /// The current user's own reaction type name, or null if they haven't
  /// reacted — `PostResponse.viewerReaction`.
  final String? viewerReaction;

  final String? shareUrl;

  /// Populated when this post is a repost — the original `PostResponse`.
  final PostEntity? originalPost;

  /// Client-local only (see class doc) — never sent to or read from the
  /// backend directly; `FeedRepositoryImpl` merges this in from
  /// `BookmarksRepository`.
  final bool savedByMe;

  /// Client-local (see class doc) — true once the viewer has reposted this
  /// post, so the repost pill can render as a two-state toggle ("Repost" /
  /// "Cancel repost") the same way the like pill already does off
  /// [likedByMe]. Never sent to or read from the backend; always `false` on
  /// a fresh fetch, then re-applied by whichever cubit is showing the post —
  /// either because it flipped this *this* session (`toggleRepost`), or
  /// because it was recovered from an earlier session at load time (see
  /// `FeedCubit._seedMyRepostIds`'s doc).
  final bool repostedByMe;

  bool get isRepost => originalPost != null;
  bool get hasImages => images.isNotEmpty;
  bool get likedByMe => viewerReaction != null;
  int get likeCount => reactionCounts['LIKE'] ?? 0;

  /// The viewer's own reaction as a typed [ReactionType], or null if they
  /// haven't reacted (or reacted with a type this client doesn't know).
  ReactionType? get viewerReactionType => ReactionType.fromWire(viewerReaction);

  /// Sum of every reaction type's count — what the pill should show once a
  /// post can carry more than just `LIKE`s (showing only [likeCount] would
  /// silently hide LOVE/HAHA/WOW/SAD/ANGRY reactions from the total).
  int get reactionTotal => reactionCounts.values.fold(0, (a, b) => a + b);

  PostEntity copyWith({
    int? commentCount,
    int? repostCount,
    Map<String, int>? reactionCounts,
    Object? viewerReaction = _unset,
    bool? savedByMe,
    bool? repostedByMe,
  }) {
    return PostEntity(
      id: id,
      authorId: authorId,
      authorUsername: authorUsername,
      authorAvatarUrl: authorAvatarUrl,
      authorFullName: authorFullName,
      createdAt: createdAt,
      content: content,
      images: images,
      visibility: visibility,
      isOwner: isOwner,
      commentCount: commentCount ?? this.commentCount,
      repostCount: repostCount ?? this.repostCount,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      viewerReaction: identical(viewerReaction, _unset) ? this.viewerReaction : viewerReaction as String?,
      shareUrl: shareUrl,
      originalPost: originalPost,
      savedByMe: savedByMe ?? this.savedByMe,
      repostedByMe: repostedByMe ?? this.repostedByMe,
    );
  }

  @override
  List<Object?> get props => [
    id,
    content,
    commentCount,
    repostCount,
    reactionCounts,
    viewerReaction,
    savedByMe,
    repostedByMe,
  ];
}

const Object _unset = Object();
