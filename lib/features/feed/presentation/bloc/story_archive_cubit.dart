import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/story_entity.dart';
import '../../domain/repositories/story_repository.dart';
import '../../domain/usecases/story_usecases.dart';

enum StoryArchiveStatus { loading, loaded, error }

/// One calendar day's worth of archived stories, newest day first. The
/// endpoint returns a flat page; grouping by day is explicitly the client's
/// job.
class StoryArchiveDay extends Equatable {
  const StoryArchiveDay({required this.day, required this.stories});

  /// Local midnight of the day these were posted on.
  final DateTime day;
  final List<StoryEntity> stories;

  @override
  List<Object?> get props => [day, stories];
}

class StoryArchiveState extends Equatable {
  const StoryArchiveState({
    this.status = StoryArchiveStatus.loading,
    this.stories = const [],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.page = 0,
    this.typeFilter,
    this.from,
    this.to,
    this.errorMessage,
  });

  final StoryArchiveStatus status;

  /// Flat and newest-first, exactly as the endpoint returns it — [days] is
  /// the grouped view the page renders.
  final List<StoryEntity> stories;
  final bool hasMore;
  final bool isLoadingMore;
  final int page;

  /// Null means both kinds.
  final StoryType? typeFilter;

  /// Inclusive UTC-day bounds, or null for "all time". Both are set or
  /// neither is — the picker returns a range.
  final DateTime? from;
  final DateTime? to;
  final String? errorMessage;

  bool get hasDateRange => from != null && to != null;

  bool get isEmpty => stories.isEmpty;

  /// [stories] folded into day buckets. Derived rather than stored so a
  /// delete or an appended page can't leave the two out of step.
  List<StoryArchiveDay> get days {
    final buckets = <DateTime, List<StoryEntity>>{};
    for (final story in stories) {
      final local = story.createdAt.toLocal();
      buckets.putIfAbsent(DateTime(local.year, local.month, local.day), () => []).add(story);
    }
    final keys = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final key in keys) StoryArchiveDay(day: key, stories: buckets[key]!)];
  }

  StoryArchiveState copyWith({
    StoryArchiveStatus? status,
    List<StoryEntity>? stories,
    bool? hasMore,
    bool? isLoadingMore,
    int? page,
    StoryType? typeFilter,
    bool clearTypeFilter = false,
    DateTime? from,
    DateTime? to,
    bool clearDateRange = false,
    String? errorMessage,
  }) {
    return StoryArchiveState(
      status: status ?? this.status,
      stories: stories ?? this.stories,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      page: page ?? this.page,
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      from: clearDateRange ? null : (from ?? this.from),
      to: clearDateRange ? null : (to ?? this.to),
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, stories, hasMore, isLoadingMore, page, typeFilter, from, to, errorMessage];
}

/// Settings → Story archive. Your own stories, expired ones included, until
/// you delete them — nobody else can read this list.
class StoryArchiveCubit extends Cubit<StoryArchiveState> {
  StoryArchiveCubit(this._getArchive, this._deleteStory) : super(const StoryArchiveState());

  final GetStoryArchiveUseCase _getArchive;
  final DeleteStoryUseCase _deleteStory;

  Future<void> load() async {
    emit(state.copyWith(status: StoryArchiveStatus.loading, page: 0));
    final result = await _getArchive(GetStoryArchiveParams(filter: _filter));
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(status: StoryArchiveStatus.error, errorMessage: failure.message)),
      (page) => emit(
        state.copyWith(
          status: StoryArchiveStatus.loaded,
          stories: page.stories,
          hasMore: page.hasMore,
          page: 0,
        ),
      ),
    );
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.status != StoryArchiveStatus.loaded) return;
    emit(state.copyWith(isLoadingMore: true));
    final next = state.page + 1;
    final result = await _getArchive(GetStoryArchiveParams(page: next, filter: _filter));
    if (isClosed) return;
    result.fold(
      (_) => emit(state.copyWith(isLoadingMore: false)),
      (page) => emit(
        state.copyWith(
          stories: [...state.stories, ...page.stories],
          hasMore: page.hasMore,
          isLoadingMore: false,
          page: next,
        ),
      ),
    );
  }

  StoryArchiveFilter get _filter =>
      StoryArchiveFilter(type: state.typeFilter, from: state.from, to: state.to);

  /// Null clears the filter (both kinds). Re-reads from page 0, since the
  /// filter is applied server-side.
  Future<void> setTypeFilter(StoryType? type) async {
    if (type == state.typeFilter) return;
    emit(state.copyWith(typeFilter: type, clearTypeFilter: type == null));
    await load();
  }

  /// Both null clears the range. The server reads these as **UTC calendar
  /// days** and rejects `to` before `from` with `400 VALIDATION_FAILED`, so
  /// a reversed pair is swapped here rather than sent.
  Future<void> setDateRange(DateTime? from, DateTime? to) async {
    if (from == null || to == null) {
      if (!state.hasDateRange) return;
      emit(state.copyWith(clearDateRange: true));
    } else {
      final ordered = from.isAfter(to) ? (to, from) : (from, to);
      if (ordered.$1 == state.from && ordered.$2 == state.to) return;
      emit(state.copyWith(from: ordered.$1, to: ordered.$2));
    }
    await load();
  }

  /// Deletes one archived story. Returns the failure message, or null on
  /// success — the page owns the snackbar.
  Future<String?> delete(String storyId) async {
    final result = await _deleteStory(storyId);
    if (isClosed) return null;
    return result.fold((failure) => failure.message, (_) {
      emit(state.copyWith(stories: state.stories.where((s) => s.id != storyId).toList()));
      return null;
    });
  }
}
