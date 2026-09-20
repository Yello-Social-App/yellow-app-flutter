import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../feed/domain/entities/post_entity.dart' show ReactionType;
import '../../domain/entities/community_entity.dart';
import '../../domain/entities/community_post_entity.dart';
import '../../domain/usecases/communities_usecases.dart';

enum CommunityDetailStatus { initial, loading, loaded, error }

class CommunityDetailState extends Equatable {
  const CommunityDetailState({
    this.status = CommunityDetailStatus.initial,
    this.community,
    this.posts = const [],
    this.sort = CommunityPostSort.hot,
    this.nextCursor,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.membershipBusy = false,
    this.errorMessage,
    this.busyIds = const {},
  });

  final CommunityDetailStatus status;

  /// Null until the first load resolves — the header renders a shimmer then.
  final CommunityEntity? community;
  final List<CommunityPostEntity> posts;
  final CommunityPostSort sort;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingMore;

  /// Join/leave in flight — one flag rather than a set, since there is only
  /// ever one community on this screen.
  final bool membershipBusy;
  final String? errorMessage;
  final Set<String> busyIds;

  /// Posting is gated server-side on membership
  /// (`403 COMMUNITY_MEMBERSHIP_REQUIRED`), so the composer entry point is
  /// hidden rather than shown-then-rejected.
  bool get canPost => community?.isMember ?? false;

  CommunityDetailState copyWith({
    CommunityDetailStatus? status,
    CommunityEntity? community,
    List<CommunityPostEntity>? posts,
    CommunityPostSort? sort,
    Object? nextCursor = _unset,
    bool? hasMore,
    bool? isLoadingMore,
    bool? membershipBusy,
    String? errorMessage,
    Set<String>? busyIds,
  }) {
    return CommunityDetailState(
      status: status ?? this.status,
      community: community ?? this.community,
      posts: posts ?? this.posts,
      sort: sort ?? this.sort,
      // See `CommunityFeedState.copyWith` — a null cursor means "no more
      // pages" and must not be coalesced away.
      nextCursor: identical(nextCursor, _unset) ? this.nextCursor : nextCursor as String?,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      membershipBusy: membershipBusy ?? this.membershipBusy,
      errorMessage: errorMessage,
      busyIds: busyIds ?? this.busyIds,
    );
  }

  @override
  List<Object?> get props => [
    status,
    community,
    posts,
    sort,
    nextCursor,
    hasMore,
    isLoadingMore,
    membershipBusy,
    errorMessage,
    busyIds,
  ];
}

/// One community's own screen: its about/rules header plus its threads.
///
/// Created per push with the community's [slug] (see `injection.dart`'s
/// `registerFactoryParam`), so navigating to a second community never reuses
/// the first one's state.
class CommunityDetailCubit extends Cubit<CommunityDetailState> {
  CommunityDetailCubit({
    required this.slug,
    required GetCommunityUseCase getCommunity,
    required GetCommunityPostsUseCase getPosts,
    required JoinCommunityUseCase joinCommunity,
    required LeaveCommunityUseCase leaveCommunity,
    required VoteCommunityPostUseCase vote,
    required ReactToCommunityPostUseCase react,
  })  : _getCommunity = getCommunity,
        _getPosts = getPosts,
        _joinCommunity = joinCommunity,
        _leaveCommunity = leaveCommunity,
        _vote = vote,
        _react = react,
        super(const CommunityDetailState());

  final String slug;
  final GetCommunityUseCase _getCommunity;
  final GetCommunityPostsUseCase _getPosts;
  final JoinCommunityUseCase _joinCommunity;
  final LeaveCommunityUseCase _leaveCommunity;
  final VoteCommunityPostUseCase _vote;
  final ReactToCommunityPostUseCase _react;

  int _generation = 0;

  Future<void> load() async {
    if (state.status == CommunityDetailStatus.loaded) return;
    await refresh();
  }

  Future<void> refresh() async {
    _generation++;
    final generation = _generation;
    emit(state.copyWith(status: CommunityDetailStatus.loading));

    // Both reads are independent, so they are started together and awaited
    // after — the header and the thread list arrive in one frame. Kept as two
    // awaits rather than a `Future.wait` list so each keeps its own
    // `Either<Failure, T>` type instead of widening to a common supertype and
    // needing a cast back out.
    final communityFuture = _getCommunity(CommunitySlugParams(slug));
    final postsFuture = _getPosts(CommunityPostsParams(slug: slug, sort: state.sort));
    final communityResult = await communityFuture;
    final postsResult = await postsFuture;
    // The screen is pushed/popped like any other, so a pop mid-flight closes
    // this factory cubit before the response lands.
    if (isClosed || generation != _generation) return;

    String? failureMessage;
    CommunityEntity? community = state.community;
    communityResult.fold((l) => failureMessage = l.message, (r) => community = r);

    // A community that failed to load is fatal for this screen; a post list
    // that failed is not — an empty thread list under a valid header is a
    // better outcome than an error page for the whole community.
    if (community == null) {
      emit(
        state.copyWith(
          status: CommunityDetailStatus.error,
          errorMessage: failureMessage ?? 'Could not load this community.',
        ),
      );
      return;
    }

    postsResult.fold(
      (failure) => emit(
        state.copyWith(
          status: CommunityDetailStatus.loaded,
          community: community,
          posts: const [],
          nextCursor: null,
          hasMore: false,
          errorMessage: failure.message,
        ),
      ),
      (page) => emit(
        state.copyWith(
          status: CommunityDetailStatus.loaded,
          community: community,
          posts: page.posts,
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      ),
    );
  }

  Future<void> setSort(CommunityPostSort sort) async {
    if (sort == state.sort) return;
    _generation++;
    final generation = _generation;
    emit(state.copyWith(sort: sort, posts: const [], nextCursor: null, hasMore: false));

    final result = await _getPosts(CommunityPostsParams(slug: slug, sort: sort));
    if (isClosed || generation != _generation) return;
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (page) => emit(
        state.copyWith(posts: page.posts, nextCursor: page.nextCursor, hasMore: page.hasMore),
      ),
    );
  }

  Future<void> loadMore() async {
    if (state.status != CommunityDetailStatus.loaded || !state.hasMore || state.isLoadingMore) return;
    final cursor = state.nextCursor;
    if (cursor == null) return;

    final generation = _generation;
    emit(state.copyWith(isLoadingMore: true));

    final result = await _getPosts(CommunityPostsParams(slug: slug, sort: state.sort, cursor: cursor));
    if (isClosed || generation != _generation) return;
    result.fold(
      (_) => emit(state.copyWith(isLoadingMore: false, hasMore: false)),
      (page) => emit(
        state.copyWith(
          posts: [...state.posts, ...page.posts],
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      ),
    );
  }

  Future<void> toggleMembership() async {
    final community = state.community;
    if (community == null || state.membershipBusy) return;
    emit(state.copyWith(membershipBusy: true));

    final params = CommunitySlugParams(community.slug);
    final result = community.isMember ? await _leaveCommunity(params) : await _joinCommunity(params);
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(membershipBusy: false, errorMessage: failure.message)),
      (updated) => emit(state.copyWith(community: updated, membershipBusy: false)),
    );
  }

  Future<void> toggleVote(CommunityPostEntity post, CommunityVote tapped) async {
    if (state.busyIds.contains(post.id)) return;
    emit(state.copyWith(busyIds: {...state.busyIds, post.id}));

    final result = await _vote(
      VoteCommunityPostParams(post: post, vote: tapped.toggledFrom(post.viewerVote)),
    );
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(errorMessage: failure.message, busyIds: {...state.busyIds}..remove(post.id)),
      ),
      (updated) => emit(
        state.copyWith(posts: _replace(updated), busyIds: {...state.busyIds}..remove(post.id)),
      ),
    );
  }

  Future<void> react(CommunityPostEntity post, ReactionType type) async {
    if (state.busyIds.contains(post.id)) return;
    emit(state.copyWith(busyIds: {...state.busyIds, post.id}));

    final result = await _react(ReactToCommunityPostParams(post: post, type: type));
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(errorMessage: failure.message, busyIds: {...state.busyIds}..remove(post.id)),
      ),
      (updated) => emit(
        state.copyWith(posts: _replace(updated), busyIds: {...state.busyIds}..remove(post.id)),
      ),
    );
  }

  /// Puts a freshly created thread at the top without a refetch, and bumps the
  /// header's member-facing post affordance — the composer returns the created
  /// `CommunityPost`, so there is nothing to re-read.
  void prepend(CommunityPostEntity post) {
    emit(state.copyWith(posts: [post, ...state.posts]));
  }

  /// Applies a change made on the thread screen (a vote, a reaction, or a new
  /// comment) back onto this list, so popping back doesn't show stale counts.
  void applyUpdated(CommunityPostEntity post) {
    emit(state.copyWith(posts: _replace(post)));
  }

  List<CommunityPostEntity> _replace(CommunityPostEntity updated) => [
    for (final post in state.posts)
      if (post.id == updated.id) updated else post,
  ];
}

const Object _unset = Object();
