import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/community_entity.dart';
import '../../domain/usecases/communities_usecases.dart';

enum CommunitiesStatus { initial, loading, loaded, error }

class CommunitiesState extends Equatable {
  const CommunitiesState({
    this.status = CommunitiesStatus.initial,
    this.communities = const [],
    this.query = '',
    this.sort = CommunitySort.popular,
    this.membership,
    this.page = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.busySlugs = const {},
  });

  final CommunitiesStatus status;
  final List<CommunityEntity> communities;
  final String query;
  final CommunitySort sort;

  /// Null means "no membership filter" — see [CommunityMembershipFilter].
  final CommunityMembershipFilter? membership;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final String? errorMessage;

  /// Slugs with an in-flight join/leave — disables that card's button only.
  final Set<String> busySlugs;

  CommunitiesState copyWith({
    CommunitiesStatus? status,
    List<CommunityEntity>? communities,
    String? query,
    CommunitySort? sort,
    CommunityMembershipFilter? membership,
    bool clearMembership = false,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    String? errorMessage,
    Set<String>? busySlugs,
  }) {
    return CommunitiesState(
      status: status ?? this.status,
      communities: communities ?? this.communities,
      query: query ?? this.query,
      sort: sort ?? this.sort,
      // `membership` is itself nullable, so "leave it alone" and "clear it"
      // cannot both be expressed by passing null — hence the explicit flag.
      membership: clearMembership ? null : (membership ?? this.membership),
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage,
      busySlugs: busySlugs ?? this.busySlugs,
    );
  }

  @override
  List<Object?> get props => [
    status,
    communities,
    query,
    sort,
    membership,
    page,
    hasMore,
    isLoadingMore,
    errorMessage,
    busySlugs,
  ];
}

/// Browse/search/filter communities — `GET /communities` (offset-paged).
///
/// Same generation-token guard as `SearchCubit`: changing the query, the sort
/// or the membership filter invalidates every request already in flight, so a
/// slow earlier response can't overwrite the newer filter's results.
class CommunitiesCubit extends Cubit<CommunitiesState> {
  CommunitiesCubit({
    required GetCommunitiesUseCase getCommunities,
    required JoinCommunityUseCase joinCommunity,
    required LeaveCommunityUseCase leaveCommunity,
  })  : _getCommunities = getCommunities,
        _joinCommunity = joinCommunity,
        _leaveCommunity = leaveCommunity,
        super(const CommunitiesState());

  final GetCommunitiesUseCase _getCommunities;
  final JoinCommunityUseCase _joinCommunity;
  final LeaveCommunityUseCase _leaveCommunity;

  static const Duration _debounce = Duration(milliseconds: 350);

  Timer? _debounceTimer;
  int _generation = 0;

  /// First load. A no-op once loaded, so re-entering the screen doesn't
  /// re-fetch — pull-to-refresh is the explicit way to do that.
  Future<void> load() async {
    if (state.status == CommunitiesStatus.loaded) return;
    await refresh();
  }

  Future<void> refresh() async {
    _debounceTimer?.cancel();
    _generation++;
    await _fetchFirstPage(_generation);
  }

  void onQueryChanged(String raw) {
    final query = raw.trim();
    if (query == state.query) return;
    _debounceTimer?.cancel();
    _generation++;
    emit(state.copyWith(query: query, status: CommunitiesStatus.loading));
    final generation = _generation;
    _debounceTimer = Timer(_debounce, () => _fetchFirstPage(generation));
  }

  Future<void> setSort(CommunitySort sort) async {
    if (sort == state.sort) return;
    _debounceTimer?.cancel();
    _generation++;
    emit(state.copyWith(sort: sort, status: CommunitiesStatus.loading));
    await _fetchFirstPage(_generation);
  }

  /// Pass null to clear the filter.
  Future<void> setMembership(CommunityMembershipFilter? membership) async {
    if (membership == state.membership) return;
    _debounceTimer?.cancel();
    _generation++;
    emit(
      state.copyWith(
        membership: membership,
        clearMembership: membership == null,
        status: CommunitiesStatus.loading,
      ),
    );
    await _fetchFirstPage(_generation);
  }

  Future<void> _fetchFirstPage(int generation) async {
    final result = await _getCommunities(
      GetCommunitiesParams(query: state.query, membership: state.membership, sort: state.sort),
    );
    if (isClosed || generation != _generation) return;
    result.fold(
      (failure) => emit(state.copyWith(status: CommunitiesStatus.error, errorMessage: failure.message)),
      (page) => emit(
        state.copyWith(
          status: CommunitiesStatus.loaded,
          communities: page.communities,
          page: 0,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      ),
    );
  }

  Future<void> loadMore() async {
    if (state.status != CommunitiesStatus.loaded || !state.hasMore || state.isLoadingMore) return;

    final generation = _generation;
    final nextPage = state.page + 1;
    emit(state.copyWith(isLoadingMore: true));

    final result = await _getCommunities(
      GetCommunitiesParams(
        query: state.query,
        membership: state.membership,
        sort: state.sort,
        page: nextPage,
      ),
    );
    if (isClosed || generation != _generation) return;
    result.fold(
      (_) => emit(state.copyWith(isLoadingMore: false, hasMore: false)),
      (page) => emit(
        state.copyWith(
          communities: [...state.communities, ...page.communities],
          page: nextPage,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      ),
    );
  }

  /// Join or leave, depending on the community's current `isMember`. Both
  /// endpoints answer with the updated community, so the row is replaced with
  /// the server's version rather than an optimistic guess at the new
  /// member count.
  Future<void> toggleMembership(CommunityEntity community) async {
    if (state.busySlugs.contains(community.slug)) return;
    emit(state.copyWith(busySlugs: {...state.busySlugs, community.slug}));

    final params = CommunitySlugParams(community.slug);
    final result = community.isMember ? await _leaveCommunity(params) : await _joinCommunity(params);
    if (isClosed) return;

    result.fold(
      (failure) => emit(
        state.copyWith(
          errorMessage: failure.message,
          busySlugs: {...state.busySlugs}..remove(community.slug),
        ),
      ),
      (updated) {
        final stillMatchesFilter = state.membership == null ||
            (state.membership == CommunityMembershipFilter.joined && updated.isMember) ||
            (state.membership == CommunityMembershipFilter.notJoined && !updated.isMember);
        emit(
          state.copyWith(
            // Under an active membership filter, a community that just stopped
            // matching is dropped rather than left on screen contradicting the
            // filter chip above it.
            communities: [
              for (final c in state.communities)
                if (c.slug != updated.slug)
                  c
                else if (stillMatchesFilter)
                  updated,
            ],
            busySlugs: {...state.busySlugs}..remove(community.slug),
          ),
        );
      },
    );
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
