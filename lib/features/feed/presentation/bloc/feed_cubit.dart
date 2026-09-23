import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../profile/domain/usecases/profile_usecases.dart';
import '../../../safety/domain/usecases/safety_usecases.dart';
import '../../domain/entities/post_entity.dart';
import '../../domain/entities/reaction_breakdown.dart';
import '../../domain/entities/story_entity.dart';
import '../../domain/usecases/delete_post_usecase.dart';
import '../../domain/usecases/get_feed_usecase.dart';
import '../../domain/usecases/get_share_link_usecase.dart';
import '../../domain/usecases/get_stories_usecase.dart';
import '../../domain/usecases/like_post_usecase.dart';
import '../../domain/usecases/react_usecases.dart';
import '../../domain/usecases/update_post_usecase.dart';

enum FeedStatus { initial, loading, loaded, error }

class FeedState extends Equatable {
  const FeedState({
    this.status = FeedStatus.initial,
    this.posts = const [],
    this.stories = const [],
    this.hasMore = false,
    this.nextCursor,
    this.isLoadingMore = false,
    this.errorMessage,
    this.me,
  });

  final FeedStatus status;
  final List<PostEntity> posts;
  final List<StoryEntity> stories;
  final bool hasMore;
  final String? nextCursor;
  final bool isLoadingMore;
  final String? errorMessage;

  /// The signed-in user's own profile — feeds the header's profile button
  /// and the "what did you notice today?" composer prompt avatar, so both
  /// show the real name/photo instead of a hardcoded placeholder. Null
  /// until the first successful `refresh()` (or if `GetMeUseCase` fails —
  /// best-effort, see `refresh()`); widgets fall back to a blank/generic
  /// avatar in that case rather than crashing.
  final UserEntity? me;

  FeedState copyWith({
    FeedStatus? status,
    List<PostEntity>? posts,
    List<StoryEntity>? stories,
    bool? hasMore,
    Object? nextCursor = _unset,
    bool? isLoadingMore,
    String? errorMessage,
    UserEntity? me,
  }) {
    return FeedState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      stories: stories ?? this.stories,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: identical(nextCursor, _unset) ? this.nextCursor : nextCursor as String?,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage,
      me: me ?? this.me,
    );
  }

  @override
  List<Object?> get props => [status, posts, stories, hasMore, isLoadingMore, errorMessage, me];
}

const Object _unset = Object();

/// Owns Home-tab state: the stories rail and the feed itself. A long-lived
/// singleton (see DI) so switching tabs and back doesn't re-fetch or lose
/// in-flight like/repost/save actions.
class FeedCubit extends Cubit<FeedState> {
  FeedCubit({
    required GetFeedUseCase getFeed,
    required GetStoriesUseCase getStories,
    required LikePostUseCase likePost,
    required ReactToPostUseCase reactToPost,
    required RepostUseCase repost,
    required ToggleSaveUseCase toggleSave,
    required GetMeUseCase getMe,
    required GetUserPostsUseCase getUserPosts,
    required GetReactionSummaryUseCase getReactionSummary,
    required UpdatePostUseCase updatePost,
    required DeletePostUseCase deletePost,
    required GetShareLinkUseCase getShareLink,
    required HidePostUseCase hidePost,
    required MuteUserUseCase muteUser,
  }) : _getFeed = getFeed,
       _getStories = getStories,
       _likePost = likePost,
       _reactToPost = reactToPost,
       _repost = repost,
       _toggleSave = toggleSave,
       _getMe = getMe,
       _getUserPosts = getUserPosts,
       _getReactionSummary = getReactionSummary,
       _updatePost = updatePost,
       _deletePost = deletePost,
       _getShareLink = getShareLink,
       _hidePost = hidePost,
       _muteUser = muteUser,
       super(const FeedState());

  final GetFeedUseCase _getFeed;
  final GetStoriesUseCase _getStories;
  final LikePostUseCase _likePost;
  final ReactToPostUseCase _reactToPost;
  final RepostUseCase _repost;
  final ToggleSaveUseCase _toggleSave;
  final GetMeUseCase _getMe;
  final GetUserPostsUseCase _getUserPosts;
  final GetReactionSummaryUseCase _getReactionSummary;
  final UpdatePostUseCase _updatePost;
  final DeletePostUseCase _deletePost;
  final GetShareLinkUseCase _getShareLink;
  final HidePostUseCase _hidePost;
  final MuteUserUseCase _muteUser;

  Future<void> load() async {
    if (state.status == FeedStatus.loaded) return;
    await refresh();
  }

  Future<void> refresh() async {
    emit(state.copyWith(status: FeedStatus.loading));

    Failure? failure;
    List<PostEntity> posts = state.posts;
    List<StoryEntity> stories = state.stories;
    bool hasMore = state.hasMore;
    String? nextCursor = state.nextCursor;
    UserEntity? me = state.me;

    (await _getFeed(const GetFeedParams())).fold((l) => failure = l, (page) {
      posts = page.posts;
      hasMore = page.hasMore;
      nextCursor = page.nextCursor;
    });
    (await _getStories(const NoParams())).fold((l) => failure ??= l, (r) => stories = r);
    // Best-effort, like `PostDetailCubit.load()`'s own `GetMeUseCase` call:
    // this app has no app-wide current-user cache, so the header/composer
    // avatar just keeps showing whatever it last had (or nothing) if this
    // one call fails — it never fails the whole feed refresh.
    (await _getMe(const NoParams())).fold((_) {}, (r) => me = r);
    final myId = me?.id;
    if (myId != null) await _seedMyRepostIds(myId);

    if (failure != null) {
      emit(state.copyWith(status: FeedStatus.error, errorMessage: failure!.message));
      return;
    }
    emit(
      state.copyWith(
        status: FeedStatus.loaded,
        posts: _withMyReposts(posts),
        stories: stories,
        hasMore: hasMore,
        nextCursor: nextCursor,
        me: me,
      ),
    );
  }

  /// Drops back to [FeedState]'s initial values and forgets in-flight
  /// bookkeeping — called when the signed-in identity changes (see
  /// `bootstrap.dart`'s `SessionManager` listener) so the next `load()`
  /// after a different account signs in doesn't short-circuit on this
  /// singleton's leftover `status: loaded` from the previous account.
  void reset() {
    _myRepostIds.clear();
    _pendingReactions.clear();
    _pendingReposts.clear();
    _pendingHides.clear();
    _pendingMutes.clear();
    emit(const FeedState());
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.nextCursor == null) return;
    emit(state.copyWith(isLoadingMore: true));
    final result = await _getFeed(GetFeedParams(cursor: state.nextCursor));
    result.fold(
      (_) => emit(state.copyWith(isLoadingMore: false)),
      (page) => emit(
        state.copyWith(
          isLoadingMore: false,
          posts: [...state.posts, ..._withMyReposts(page.posts)],
          hasMore: page.hasMore,
          nextCursor: page.nextCursor,
        ),
      ),
    );
  }

  /// Re-applies [_myRepostIds] onto a freshly-fetched page: every fetch
  /// starts every post at `repostedByMe: false` (the backend has no such
  /// field — see [PostEntity.repostedByMe]'s doc), so without this a
  /// pull-to-refresh right after reposting something would flip that pill
  /// back to "Repost" even though [_myRepostIds] still has it, letting a
  /// second tap create a duplicate repost instead of cancelling the first.
  List<PostEntity> _withMyReposts(List<PostEntity> posts) =>
      posts.map((p) => _myRepostIds.containsKey(p.id) ? p.copyWith(repostedByMe: true) : p).toList();

  /// Adds a freshly published/reposted post to the top of the feed without
  /// a full refetch.
  void prependPost(PostEntity post) => emit(state.copyWith(posts: [post, ...state.posts]));

  /// Replaces a single post in place (e.g. after editing it elsewhere).
  void replacePost(PostEntity post) => _replace(post.id, (_) => post);

  /// Drops a post from the feed (e.g. after deleting it elsewhere).
  void removePost(String id) => emit(state.copyWith(posts: state.posts.where((p) => p.id != id).toList()));

  /// Re-fetches just the stories rail — cheap (device-local), used after
  /// returning from the story viewer so seen/unseen rings stay in sync.
  Future<void> reloadStories() async {
    final result = await _getStories(const NoParams());
    result.fold((_) {}, (stories) => emit(state.copyWith(stories: stories)));
  }

  void _replace(String id, PostEntity Function(PostEntity) update) {
    final index = state.posts.indexWhere((p) => p.id == id);
    if (index == -1) return;
    final next = [...state.posts];
    next[index] = update(next[index]);
    emit(state.copyWith(posts: next));
  }

  /// Post ids with a reaction PUT/DELETE currently in flight — shared by
  /// [toggleLike] and [react] since both mutate the same underlying
  /// reaction. Without this, a fast double-tap (easy to do on the like
  /// pill) fires a second request before the first response has updated
  /// `post.likedByMe`, so both go out as "add LIKE" instead of the second
  /// one correctly toggling it back off — the backend ends up with two
  /// reactions recorded for one tap. The feed card then shows whatever the
  /// *first* response said (this cubit never re-fetches after a react), so
  /// the inflated true count only surfaces later, e.g. opening post detail
  /// re-fetches the post and shows one more like than the feed card does.
  /// A plain field rather than `FeedState` — nothing renders a per-post
  /// "reacting" indicator today, so it's re-entrancy bookkeeping only, not
  /// equatable UI state.
  final Set<String> _pendingReactions = {};

  /// Flips the pill immediately on tap (see [_predictReaction]) rather than
  /// waiting on the full `POST /reactions` round trip against the live
  /// backend just to show what the tap already implies — that wait was
  /// reported as the like/repost buttons feeling "slow". The real response
  /// still wins the moment it arrives; a failed request rolls back to
  /// [post] unchanged instead of leaving an unconfirmed guess on screen.
  Future<void> toggleLike(PostEntity post) async {
    if (!_pendingReactions.add(post.id)) return;
    _replace(post.id, (current) => _predictReaction(current, ReactionType.like));
    try {
      final result = await _likePost(post);
      result.fold((_) => _replace(post.id, (_) => post), (updated) => _replace(post.id, (_) => updated));
    } finally {
      _pendingReactions.remove(post.id);
    }
  }

  /// Sets/switches/removes [post]'s reaction to [type] — the long-press
  /// reaction-picker path (see [toggleLike] for the plain single-tap path
  /// and its identical optimistic-update reasoning).
  Future<void> react(PostEntity post, ReactionType type) async {
    if (!_pendingReactions.add(post.id)) return;
    _replace(post.id, (current) => _predictReaction(current, type));
    try {
      final result = await _reactToPost(ReactToPostParams(post: post, type: type));
      result.fold((_) => _replace(post.id, (_) => post), (updated) => _replace(post.id, (_) => updated));
    } finally {
      _pendingReactions.remove(post.id);
    }
  }

  /// Predicts the toggle-reaction endpoint's own add/change/remove decision
  /// (`FeedRepositoryImpl.reactToPost`'s doc: the server always decides from
  /// the viewer's *current* reaction) so [toggleLike]/[react] can apply it
  /// locally the instant a tap lands. Purely a UI guess — the awaited
  /// response is still the source of truth and overwrites this the moment
  /// it lands.
  PostEntity _predictReaction(PostEntity post, ReactionType type) {
    final current = post.viewerReactionType;
    final next = current == type ? null : type;
    final counts = Map<String, int>.from(post.reactionCounts);
    if (current != null) {
      final left = (counts[current.wireValue] ?? 1) - 1;
      if (left > 0) {
        counts[current.wireValue] = left;
      } else {
        counts.remove(current.wireValue);
      }
    }
    if (next != null) counts[next.wireValue] = (counts[next.wireValue] ?? 0) + 1;
    return post.copyWith(reactionCounts: counts, viewerReaction: next?.wireValue);
  }

  Future<void> toggleSave(String postId) async {
    final result = await _toggleSave(PostIdParams(postId));
    result.fold((_) {}, (saved) => _replace(postId, (p) => p.copyWith(savedByMe: saved)));
  }

  /// The viewer's own repost of a given original post id — keyed by the
  /// *original* post's id, valued by the repost post's own id (the one
  /// [toggleRepost] must `DELETE` to cancel). Populated two ways: locally by
  /// [toggleRepost] the moment it acts on a post this session, and recovered
  /// from the backend at load time by [_seedMyRepostIds] — see both docs.
  /// See [PostEntity.repostedByMe]'s doc for why this can't just be a field
  /// read straight off the wire.
  final Map<String, String> _myRepostIds = {};

  /// Safety cap on how many pages of the current user's own posts
  /// [_seedMyRepostIds] will scan — bounds an unusually prolific poster's
  /// account to a fixed number of requests instead of an unbounded loop.
  /// 25 pages * the backend's fixed page size of 20 = the most recent 500
  /// of the viewer's own posts/reposts get checked.
  static const _maxRepostScanPages = 25;

  /// Rebuilds [_myRepostIds] from the source of truth — the viewer's own
  /// posts (`GET /users/{id}/posts`), which already contains every repost
  /// they've ever made (`PostResponse.originalPost` non-null) — instead of
  /// relying solely on reposts/cancels made *this* session.
  ///
  /// Without this, [_myRepostIds] starts empty on every cold app start (it's
  /// a plain in-memory field — see its own doc), so a repost made in a
  /// *previous* session would silently forget itself: [PostEntity.repostedByMe]
  /// would read `false` again even though the repost still exists server-side,
  /// the pill would show "Repost" instead of "Cancel repost", and tapping it
  /// created a second, genuinely duplicate repost of the same original post.
  /// Reported by the user as "I can repost the same post twice" after
  /// closing and reopening the app.
  ///
  /// Paginates until the backend reports no more pages (or
  /// [_maxRepostScanPages] is hit) rather than only checking page 0, since an
  /// older repost can easily have been pushed off the first page by newer
  /// posts. Merges into the existing map rather than replacing it, so a
  /// repost made moments ago in *this* session isn't briefly lost if it
  /// hasn't propagated to this list endpoint yet (this backend has shown
  /// brief cross-endpoint read lag before — see reaction-count memory).
  /// Best-effort like the `_getMe` call above: a failing page just stops the
  /// scan early instead of failing the whole feed refresh.
  Future<void> _seedMyRepostIds(String myUserId) async {
    for (var page = 0; page < _maxRepostScanPages; page++) {
      final result = await _getUserPosts(GetUserPostsParams(userId: myUserId, page: page));
      var hasMore = false;
      final failed = result.isLeft();
      result.fold((_) {}, (data) {
        hasMore = data.hasMore;
        for (final p in data.posts) {
          if (p.isRepost) _myRepostIds[p.originalPost!.id] = p.id;
        }
      });
      if (failed || !hasMore) break;
    }
  }

  /// Post ids with a repost create/cancel currently in flight — same
  /// re-entrancy guard as [_pendingReactions] and for the identical reason:
  /// without it, a fast double-tap on the repost pill could fire a second
  /// create before the first response lands (two reposts for one tap), or
  /// race a cancel against a create.
  final Set<String> _pendingReposts = {};

  /// Toggles [post]'s repost state — two outcomes, same shape as
  /// [toggleLike]: reposts it if the viewer hasn't reposted it yet this
  /// session ([PostEntity.repostedByMe] false), or deletes the viewer's own
  /// repost (found via [_myRepostIds]) if they have. Replaces the plain
  /// "always create another repost" `repostPost` this used to be — that
  /// let repeated taps pile up unbounded reposts with no way back.
  ///
  /// Flips the pill/count optimistically before the create/delete request
  /// even goes out — same reasoning as [toggleLike]'s doc — and rolls back
  /// to [post] unchanged if that request fails.
  Future<void> toggleRepost(PostEntity post) async {
    if (!_pendingReposts.add(post.id)) return;
    try {
      if (post.repostedByMe) {
        final myRepostId = _myRepostIds[post.id];
        if (myRepostId == null) return;
        _replace(post.id, (p) => p.copyWith(repostCount: p.repostCount - 1, repostedByMe: false));
        final result = await _deletePost(myRepostId);
        result.fold((_) => _replace(post.id, (_) => post), (_) {
          _myRepostIds.remove(post.id);
          removePost(myRepostId);
        });
      } else {
        _replace(post.id, (p) => p.copyWith(repostCount: p.repostCount + 1, repostedByMe: true));
        final result = await _repost(RepostParams(postId: post.id));
        result.fold((_) => _replace(post.id, (_) => post), (newPost) {
          _myRepostIds[post.id] = newPost.id;
          prependPost(newPost);
        });
      }
    } finally {
      _pendingReposts.remove(post.id);
    }
  }

  /// Edits a post you own (only non-null fields change) — backs the feed
  /// card's own "···" → "Edit post" sheet, same `PUT /api/v1/posts/{id}`
  /// `PostDetailCubit.updatePost` uses for the detail screen. Returns
  /// success so the edit sheet can pop itself / show an error.
  Future<bool> updatePost(String postId, {String? content, PostVisibility? visibility}) async {
    final result = await _updatePost(UpdatePostParams(postId: postId, content: content, visibility: visibility));
    return result.fold((_) => false, (updated) {
      _replace(postId, (_) => updated);
      return true;
    });
  }

  /// Deletes a post you own — `DELETE /api/v1/posts/{id}`. Drops it from
  /// [FeedState.posts] on success; the feed card's "···" menu is the only
  /// caller today.
  Future<bool> deletePost(String postId) async {
    final result = await _deletePost(postId);
    return result.fold((_) => false, (_) {
      removePost(postId);
      return true;
    });
  }

  /// The post's public share URL, or null on failure — same on-demand call
  /// `PostDetailCubit.getShareLink` makes, for the feed card's own menu.
  Future<String?> getShareLink(String postId) async {
    final result = await _getShareLink(postId);
    return result.fold((_) => null, (url) => url);
  }

  /// On-demand reaction breakdown for the feed card's own "View reactions".
  Future<ReactionBreakdown?> getReactionSummary(String postId) async {
    final result = await _getReactionSummary(GetReactionSummaryParams(targetType: 'POST', targetId: postId));
    return result.fold((_) => null, (summary) => summary);
  }

  /// Post ids with a hide in flight — the same re-entrancy guard as
  /// [_pendingReactions]. The card disappears on success, so a double-tap
  /// would otherwise fire a second `POST …/hide` at a post that is no
  /// longer on screen.
  final Set<String> _pendingHides = {};

  /// Hides one post from this account's feed, everywhere — `POST
  /// /v1/posts/{id}/hide`, which the backend honours on every device, not
  /// just this one. Drops the card on success.
  ///
  /// Not optimistic, unlike [toggleLike]: the card vanishing *is* the
  /// feedback, and a card that vanished for a request that then failed
  /// would come back on the next refresh with no explanation.
  Future<bool> hidePost(String postId) async {
    if (!_pendingHides.add(postId)) return false;
    try {
      final result = await _hidePost(HidePostParams(postId));
      return result.fold((_) => false, (_) {
        removePost(postId);
        return true;
      });
    } finally {
      _pendingHides.remove(postId);
    }
  }

  /// User ids with a mute in flight — see [_pendingHides].
  final Set<String> _pendingMutes = {};

  /// Mutes a post's author — `POST /v1/users/{id}/mute`. The server leaves
  /// muted authors out of `/feed` from the next fetch on, so this drops
  /// what is already on screen to match, rather than leaving their posts
  /// sitting there until the next refresh.
  ///
  /// A repost of someone else's post is dropped by its *reposter*: that is
  /// whose name is on the card in the feed, and whose posts the mute
  /// actually filters.
  Future<bool> muteAuthor(String userId) async {
    if (!_pendingMutes.add(userId)) return false;
    try {
      final result = await _muteUser(MuteParams(userId));
      return result.fold((_) => false, (_) {
        emit(state.copyWith(posts: state.posts.where((p) => p.authorId != userId).toList()));
        return true;
      });
    } finally {
      _pendingMutes.remove(userId);
    }
  }
}
