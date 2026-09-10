import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/story_entity.dart';
import '../../domain/usecases/get_stories_usecase.dart';
import '../../domain/usecases/mark_story_seen_usecase.dart';

enum StoryStatus { loading, playing, error, finished }

class StoryState extends Equatable {
  const StoryState({
    this.status = StoryStatus.loading,
    this.stories = const [],
    this.userIndex = 0,
    this.segmentIndex = 0,
    this.progress = 0,
    this.liked = false,
    this.errorMessage,
  });

  final StoryStatus status;
  final List<StoryEntity> stories;
  final int userIndex;
  final int segmentIndex;

  /// 0-100 within the current segment.
  final double progress;
  final bool liked;
  final String? errorMessage;

  StoryEntity? get currentUser => userIndex < stories.length ? stories[userIndex] : null;
  StorySegmentEntity? get currentSegment {
    final user = currentUser;
    if (user == null || segmentIndex >= user.segments.length) return null;
    return user.segments[segmentIndex];
  }

  StoryState copyWith({
    StoryStatus? status,
    List<StoryEntity>? stories,
    int? userIndex,
    int? segmentIndex,
    double? progress,
    bool? liked,
    String? errorMessage,
  }) {
    return StoryState(
      status: status ?? this.status,
      stories: stories ?? this.stories,
      userIndex: userIndex ?? this.userIndex,
      segmentIndex: segmentIndex ?? this.segmentIndex,
      progress: progress ?? this.progress,
      liked: liked ?? this.liked,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, stories, userIndex, segmentIndex, progress, liked];
}

/// Drives the full-screen story viewer: a ticking progress bar per segment
/// that auto-advances through a user's segments, then to the next user,
/// then signals [StoryStatus.finished] so the page can pop.
class StoryCubit extends Cubit<StoryState> {
  StoryCubit(this._getStories, this._markStorySeen) : super(const StoryState());

  final GetStoriesUseCase _getStories;
  final MarkStorySeenUseCase _markStorySeen;
  Timer? _timer;
  DateTime _segmentStart = DateTime.now();

  Future<void> start(int initialUserIndex) async {
    final result = await _getStories(const NoParams());
    result.fold(
      (failure) => emit(state.copyWith(status: StoryStatus.error, errorMessage: failure.message)),
      (stories) {
        if (stories.isEmpty || initialUserIndex >= stories.length) {
          emit(state.copyWith(status: StoryStatus.finished));
          return;
        }
        emit(StoryState(status: StoryStatus.playing, stories: stories, userIndex: initialUserIndex));
        _markCurrentSeen();
        _runSegment();
      },
    );
  }

  /// Fire-and-forget — flips the current user's tray to seen without
  /// blocking playback (device-local, see `StoryLocalDataSource`).
  void _markCurrentSeen() {
    final user = state.currentUser;
    if (user == null || user.seen) return;
    _markStorySeen(user.userId);
  }

  void _runSegment() {
    _timer?.cancel();
    _segmentStart = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final elapsed = DateTime.now().difference(_segmentStart);
      final pct = (elapsed.inMilliseconds / AppConstants.storySegmentDuration.inMilliseconds * 100)
          .clamp(0, 100)
          .toDouble();
      if (pct < 100) {
        emit(state.copyWith(progress: pct));
        return;
      }
      next();
    });
  }

  void next() {
    final user = state.currentUser;
    if (user == null) return _finish();

    if (state.segmentIndex < user.segments.length - 1) {
      emit(state.copyWith(segmentIndex: state.segmentIndex + 1, progress: 0));
      _runSegment();
      return;
    }
    if (state.userIndex < state.stories.length - 1) {
      emit(state.copyWith(userIndex: state.userIndex + 1, segmentIndex: 0, progress: 0, liked: false));
      _markCurrentSeen();
      _runSegment();
      return;
    }
    _finish();
  }

  void previous() {
    if (state.segmentIndex > 0) {
      emit(state.copyWith(segmentIndex: state.segmentIndex - 1, progress: 0));
      _runSegment();
      return;
    }
    if (state.userIndex > 0) {
      final prevUser = state.stories[state.userIndex - 1];
      emit(state.copyWith(
        userIndex: state.userIndex - 1,
        segmentIndex: prevUser.segments.length - 1,
        progress: 0,
      ));
      _markCurrentSeen();
      _runSegment();
      return;
    }
    emit(state.copyWith(progress: 0));
    _runSegment();
  }

  void toggleLike() => emit(state.copyWith(liked: !state.liked));

  void _finish() {
    _timer?.cancel();
    emit(state.copyWith(status: StoryStatus.finished));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
