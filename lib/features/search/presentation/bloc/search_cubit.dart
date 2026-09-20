import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../feed/domain/entities/reactor_entity.dart' show FriendRelationStatus;
import '../../../friends/domain/usecases/friends_usecases.dart';
import '../../domain/entities/user_search_result_entity.dart';
import '../../domain/usecases/search_users_usecase.dart';

/// `idle` covers both "nothing typed yet" and "still under the backend's
/// two-character minimum" — in both cases there is no request to make and
/// nothing to show but the prompt.
enum SearchStatus { idle, loading, loaded, error }

class SearchState extends Equatable {
  const SearchState({
    this.status = SearchStatus.idle,
    this.query = '',
    this.results = const [],
    this.page = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.busyIds = const {},
  });

  final SearchStatus status;

  /// The trimmed query the current [results] belong to — not the raw text in
  /// the field, which may be mid-debounce.
  final String query;
  final List<UserSearchResultEntity> results;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final String? errorMessage;

  /// User ids with an in-flight friend request — disables just that row's
  /// button instead of the whole list.
  final Set<String> busyIds;

  bool get isEmptyResult => status == SearchStatus.loaded && results.isEmpty;

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    List<UserSearchResultEntity>? results,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    String? errorMessage,
    Set<String>? busyIds,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      results: results ?? this.results,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage,
      busyIds: busyIds ?? this.busyIds,
    );
  }

  @override
  List<Object?> get props => [status, query, results, page, hasMore, isLoadingMore, errorMessage, busyIds];
}

/// People search over `GET /users/search`.
///
/// Debouncing lives here rather than in the widget so the page stays a dumb
/// `onChanged` → cubit call, and so a keystroke that arrives while a request
/// is already out can cancel it logically: every request carries the
/// [_generation] it was issued under, and a response from an older generation
/// is dropped instead of overwriting the newer query's results (the classic
/// "results flash back to the previous query" bug when the network reorders
/// two in-flight searches).
class SearchCubit extends Cubit<SearchState> {
  SearchCubit({required SearchUsersUseCase searchUsers, required SendFriendRequestUseCase sendFriendRequest})
      : _searchUsers = searchUsers,
        _sendFriendRequest = sendFriendRequest,
        super(const SearchState());

  final SearchUsersUseCase _searchUsers;
  final SendFriendRequestUseCase _sendFriendRequest;

  static const Duration _debounce = Duration(milliseconds: 350);

  Timer? _debounceTimer;
  int _generation = 0;

  /// Call on every keystroke. Short queries settle straight to [SearchStatus.idle]
  /// without a request; anything longer is searched once typing pauses.
  void onQueryChanged(String raw) {
    final query = raw.trim();
    _debounceTimer?.cancel();
    _generation++;

    if (query.length < kUserSearchMinChars) {
      emit(
        state.copyWith(
          status: SearchStatus.idle,
          query: query,
          results: const [],
          page: 0,
          hasMore: false,
          isLoadingMore: false,
        ),
      );
      return;
    }

    emit(state.copyWith(status: SearchStatus.loading, query: query));
    final generation = _generation;
    _debounceTimer = Timer(_debounce, () => _search(query, generation));
  }

  /// Re-runs the current query — the retry action on the error state.
  Future<void> retry() async {
    final query = state.query;
    if (query.length < kUserSearchMinChars) return;
    _debounceTimer?.cancel();
    _generation++;
    emit(state.copyWith(status: SearchStatus.loading));
    await _search(query, _generation);
  }

  Future<void> _search(String query, int generation) async {
    final result = await _searchUsers(SearchUsersParams(query: query));
    if (isClosed || generation != _generation) return;
    result.fold(
      (failure) => emit(state.copyWith(status: SearchStatus.error, errorMessage: failure.message)),
      (page) => emit(
        state.copyWith(
          status: SearchStatus.loaded,
          results: page.users,
          page: 0,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      ),
    );
  }

  Future<void> loadMore() async {
    if (state.status != SearchStatus.loaded || !state.hasMore || state.isLoadingMore) return;

    final generation = _generation;
    final nextPage = state.page + 1;
    emit(state.copyWith(isLoadingMore: true));

    final result = await _searchUsers(SearchUsersParams(query: state.query, page: nextPage));
    if (isClosed || generation != _generation) return;
    result.fold(
      // A failed "load more" keeps the rows already on screen — only the
      // footer spinner goes away, same as the feed's own pagination.
      (_) => emit(state.copyWith(isLoadingMore: false, hasMore: false)),
      (page) => emit(
        state.copyWith(
          results: [...state.results, ...page.users],
          page: nextPage,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      ),
    );
  }

  /// Sends a friend request straight from a result row. The row's
  /// `friendStatus` is what the button renders off, so on success it flips to
  /// [FriendRelationStatus.requestSent] locally rather than re-running the
  /// whole search to see the same change come back.
  Future<void> sendRequest(String userId) async {
    if (state.busyIds.contains(userId)) return;
    emit(state.copyWith(busyIds: {...state.busyIds, userId}));

    final result = await _sendFriendRequest(UserIdParams(userId));
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(errorMessage: failure.message, busyIds: {...state.busyIds}..remove(userId)),
      ),
      (_) => emit(
        state.copyWith(
          results: [
            for (final user in state.results)
              if (user.id == userId) user.copyWith(friendStatus: FriendRelationStatus.requestSent) else user,
          ],
          busyIds: {...state.busyIds}..remove(userId),
        ),
      ),
    );
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
