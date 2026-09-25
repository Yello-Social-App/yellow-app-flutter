import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/story_entity.dart';
import '../../domain/usecases/story_usecases.dart';

enum StoryViewersStatus { loading, loaded, error }

class StoryViewersState extends Equatable {
  const StoryViewersState({
    this.status = StoryViewersStatus.loading,
    this.viewers = const [],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.page = 0,
    this.errorMessage,
  });

  final StoryViewersStatus status;
  final List<StoryViewerEntity> viewers;
  final bool hasMore;
  final bool isLoadingMore;
  final int page;
  final String? errorMessage;

  StoryViewersState copyWith({
    StoryViewersStatus? status,
    List<StoryViewerEntity>? viewers,
    bool? hasMore,
    bool? isLoadingMore,
    int? page,
    String? errorMessage,
  }) {
    return StoryViewersState(
      status: status ?? this.status,
      viewers: viewers ?? this.viewers,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      page: page ?? this.page,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, viewers, hasMore, isLoadingMore, page, errorMessage];
}

/// "Seen by" on your own story (`GET /stories/{id}/viewers`).
///
/// The list is deleted 48 h after the story was posted while
/// `Story.viewCount` keeps the number, so an empty page here is a normal
/// outcome on an older archived story, not a failure — the sheet says
/// "Seen by {viewCount}" without names in that case.
class StoryViewersCubit extends Cubit<StoryViewersState> {
  StoryViewersCubit(this._getViewers) : super(const StoryViewersState());

  final GetStoryViewersUseCase _getViewers;

  late String _storyId;

  Future<void> load(String storyId) async {
    _storyId = storyId;
    emit(const StoryViewersState());
    final result = await _getViewers(GetStoryViewersParams(storyId: storyId));
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(status: StoryViewersStatus.error, errorMessage: failure.message)),
      (page) => emit(
        state.copyWith(status: StoryViewersStatus.loaded, viewers: page.viewers, hasMore: page.hasMore, page: 0),
      ),
    );
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.status != StoryViewersStatus.loaded) return;
    emit(state.copyWith(isLoadingMore: true));
    final next = state.page + 1;
    final result = await _getViewers(GetStoryViewersParams(storyId: _storyId, page: next));
    if (isClosed) return;
    result.fold(
      // A failed "load more" keeps the rows already on screen and just
      // drops the footer spinner — see `PagedListView`'s own note.
      (_) => emit(state.copyWith(isLoadingMore: false)),
      (page) => emit(
        state.copyWith(
          viewers: [...state.viewers, ...page.viewers],
          hasMore: page.hasMore,
          isLoadingMore: false,
          page: next,
        ),
      ),
    );
  }
}
