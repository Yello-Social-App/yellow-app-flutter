import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../feed/domain/entities/post_entity.dart' show ReactionType;
import '../../domain/entities/community_post_entity.dart';
import '../../domain/usecases/communities_usecases.dart';

enum CommunityFeedStatus { initial, loading, loaded, error }

class CommunityFeedState extends Equatable {
  const CommunityFeedState({
    this.status = CommunityFeedStatus.initial,
    this.posts = const [],
    this.scope = CommunityFeedScope.all,
    this.sort = CommunityPostSort.hot,
    this.nextCursor,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.busyIds = const {},
  });

  final CommunityFeedStatus status;
  final List<CommunityPostEntity> posts;
  final CommunityFeedScope scope;
  final CommunityPostSort sort;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingMore;
  final String? errorMessage;

  /// Post ids with an in-flight vote or reaction. Double-tapping a vote arrow
  /// would otherwise fire two absolute-value writes whose responses can land
  /// out of order, leaving the arrow lit with the wrong score — the same
  /// missing-guard shape that once double-fired the feed's reaction endpoint.
  final Set<String> busyIds;

  CommunityFeedState copyWith({
    CommunityFeedStatus? status,
    List<CommunityPostEntity>? posts,
    CommunityFeedScope? scope,
    CommunityPostSort? sort,
    Object? nextCursor = _unset,
    bool? hasMore,
    bool? isLoadingMore,
    String? errorMessage,
    Set<String>? busyIds,
  }) {
    return CommunityFeedState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      scope: scope ?? this.scope,
      sort: sort ?? this.sort,
      // Sentinel rather than `?? this.nextCursor`: reaching the end of the
      // list is signalled by a *null* `nextCursor`, so the usual null-coalesce
      // would silently retain the exhausted page's cursor.
      nextCursor: identical(nextCursor, _unset) ? this.nextCursor : nextCursor as String?,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage,
      busyIds: busyIds ?? this.busyIds,
    );
  }

  @override
  List<Object?> get props => [
    status,
    posts,
    scope,
    sort,
    nextCursor,
    hasMore,
    isLoadingMore,
    errorMessage,
    busyIds,
  ];
}

/// The cross-community timeline — `GET /community-posts`, cursor-paged.
class CommunityFeedCubit extends Cubit<CommunityFeedState> {
  CommunityFeedCubit({
    required GetCommunityFeedUseCase getFeed,
    required VoteCommunityPostUseCase vote,
    required ReactToCommunityPostUseCase react,
  })  : _getFeed = getFeed,
        _vote = vote,
        _react = react,
        super(const CommunityFeedState());

  final GetCommunityFeedUseCase _getFeed;
  final VoteCommunityPostUseCase _vote;
  final ReactToCommunityPostUseCase _react;

  int _generation = 0;

  Future<void> load() async {
    if (state.status == CommunityFeedStatus.loaded) return;
    await refresh();
  }

  /// Re-fetches from the start. Deliberately does not blank the list while it
  /// runs, so pull-to-refresh doesn't flash an empty screen.
  Future<void> refresh() async {
    _generation++;
    final generation = _generation;
    emit(state.copyWith(status: CommunityFeedStatus.loading));

    final result = await _getFeed(CommunityFeedParams(scope: state.scope, sort: state.sort));
    if (isClosed || generation != _generation) return;
    result.fold(
      (failure) => emit(state.copyWith(status: CommunityFeedStatus.error, errorMessage: failure.message)),
      (page) => emit(
        state.copyWith(
          status: CommunityFeedStatus.loaded,
          posts: page.posts,
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      ),
    );
  }

  Future<void> setScope(CommunityFeedScope scope) async {
    if (scope == state.scope) return;
    emit(state.copyWith(scope: scope, status: CommunityFeedStatus.loading, posts: const []));
    await refresh();
  }

  Future<void> setSort(CommunityPostSort sort) async {
    if (sort == state.sort) return;
    emit(state.copyWith(sort: sort, status: CommunityFeedStatus.loading, posts: const []));
    await refresh();
  }

  Future<void> loadMore() async {
    if (state.status != CommunityFeedStatus.loaded || !state.hasMore || state.isLoadingMore) return;
    final cursor = state.nextCursor;
    if (cursor == null) return;

    final generation = _generation;
    emit(state.copyWith(isLoadingMore: true));

    final result = await _getFeed(
      CommunityFeedParams(scope: state.scope, sort: state.sort, cursor: cursor),
    );
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

  /// Applies [tapped] as a toggle: tapping the arrow already lit clears the
  /// vote, because the endpoint takes an absolute value rather than a delta.
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

  /// Applies a change made on the thread screen (a vote, a reaction, or a new
  /// comment) back onto this timeline, so popping back doesn't show stale
  /// counts — the same handoff `CommunityDetailCubit.applyUpdated` does for a
  /// single community's list. See ADR-032.
  void applyUpdated(CommunityPostEntity post) => emit(state.copyWith(posts: _replace(post)));

  /// Swaps one post in place, keeping list order — a re-sort here would move a
  /// row out from under the finger that just voted on it, even though the
  /// server's `hot` ordering has genuinely changed.
  List<CommunityPostEntity> _replace(CommunityPostEntity updated) => [
    for (final post in state.posts)
      if (post.id == updated.id) updated else post,
  ];
}

const Object _unset = Object();
