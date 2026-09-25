import 'dart:async';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/story_entity.dart';
import '../../domain/usecases/story_usecases.dart';

enum StoryStatus { loading, playing, error, finished }

class StoryState extends Equatable {
  const StoryState({
    this.status = StoryStatus.loading,
    this.rings = const [],
    this.ringIndex = 0,
    this.slideIndex = 0,
    this.progress = 0,
    this.paused = false,
    this.replying = false,
    this.errorMessage,
  });

  final StoryStatus status;
  final List<StoryRingEntity> rings;
  final int ringIndex;
  final int slideIndex;

  /// 0-1 within the current slide.
  final double progress;

  /// Held by a long-press, an open reply field, or an in-flight action.
  final bool paused;

  /// A reply is in flight — the send button shows a spinner and the field
  /// is locked so the same text can't be posted twice.
  final bool replying;

  final String? errorMessage;

  StoryRingEntity? get currentRing => ringIndex < rings.length ? rings[ringIndex] : null;

  StoryEntity? get currentStory {
    final ring = currentRing;
    if (ring == null || slideIndex >= ring.stories.length) return null;
    return ring.stories[slideIndex];
  }

  /// Your own story: no reply box, a view count and a delete action instead.
  bool get isOwnStory => currentStory?.isOwner ?? false;

  StoryState copyWith({
    StoryStatus? status,
    List<StoryRingEntity>? rings,
    int? ringIndex,
    int? slideIndex,
    double? progress,
    bool? paused,
    bool? replying,
    String? errorMessage,
  }) {
    return StoryState(
      status: status ?? this.status,
      rings: rings ?? this.rings,
      ringIndex: ringIndex ?? this.ringIndex,
      slideIndex: slideIndex ?? this.slideIndex,
      progress: progress ?? this.progress,
      paused: paused ?? this.paused,
      replying: replying ?? this.replying,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, rings, ringIndex, slideIndex, progress, paused, replying, errorMessage];
}

/// Drives the full-screen story viewer: a ticking progress bar per slide
/// that auto-advances through one author's ring, then on to the next ring,
/// then signals [StoryStatus.finished] so the page can pop.
///
/// Registered as a **factory** — one viewer session, disposed with the page.
class StoryCubit extends Cubit<StoryState> {
  StoryCubit({
    required GetStoryRailUseCase getRail,
    required GetUserStoriesUseCase getUserStories,
    required GetStoryUseCase getStory,
    required MarkStoryViewedUseCase markViewed,
    required DeleteStoryUseCase deleteStory,
    required ReplyToStoryUseCase replyToStory,
  })  : _getRail = getRail,
        _getUserStories = getUserStories,
        _getStory = getStory,
        _markViewed = markViewed,
        _deleteStory = deleteStory,
        _replyToStory = replyToStory,
        super(const StoryState());

  final GetStoryRailUseCase _getRail;
  final GetUserStoriesUseCase _getUserStories;
  final GetStoryUseCase _getStory;
  final MarkStoryViewedUseCase _markViewed;
  final DeleteStoryUseCase _deleteStory;
  final ReplyToStoryUseCase _replyToStory;

  static const Duration _tick = Duration(milliseconds: 60);

  Timer? _timer;

  /// Time already spent on the current slide before the latest resume — a
  /// pause has to keep it, or every long-press would restart the slide.
  Duration _elapsed = Duration.zero;
  DateTime _resumedAt = DateTime.now();

  /// Story ids this session has already marked viewed. `POST /view` is
  /// idempotent server-side, but going back and forth over three slides
  /// would otherwise fire a request per pass against a 120/min budget.
  final Set<String> _viewed = {};

  final Random _random = Random();

  /// Opens the rail at [authorId]'s ring, then plays on through the rest of
  /// the rail. Falls back to the first ring when that author has since
  /// dropped out of the feed (their last story expired between the rail
  /// loading and the tap).
  Future<void> start(String authorId) async {
    final result = await _getRail(const NoParams());
    // The viewer can be backed out of before this resolves, closing this
    // factory cubit — same guard `ReactorsCubit.load()` documents.
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(status: StoryStatus.error, errorMessage: failure.message)),
      (rail) {
        final rings = rail.all;
        if (rings.isEmpty) {
          emit(state.copyWith(status: StoryStatus.finished));
          return;
        }
        final index = rail.indexOfAuthor(authorId);
        _begin(rings, index == -1 ? 0 : index);
      },
    );
  }

  /// Opens one user's ring on its own (`GET /users/{id}/stories`) — a deep
  /// link, or a ring opened from outside the Home tab, where the rail is not
  /// what the viewer is playing through. Ends after that ring.
  Future<void> startForUser(String authorId) async {
    final result = await _getUserStories(authorId);
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(status: StoryStatus.error, errorMessage: failure.message)),
      (stories) {
        if (stories.isEmpty) {
          emit(state.copyWith(status: StoryStatus.finished));
          return;
        }
        final ring = StoryRingEntity(
          // The story's own author, not the stub the caller passed: a deep
          // link knows only the id, and the header needs the real name and
          // avatar.
          author: stories.first.author,
          stories: stories,
          hasUnseen: stories.any((s) => !s.isSeen),
          latestAt: stories.map((s) => s.createdAt).reduce((a, b) => a.isAfter(b) ? a : b),
          isMine: stories.first.isOwner,
        );
        _begin([ring], 0);
      },
    );
  }

  void _begin(List<StoryRingEntity> rings, int ringIndex) {
    emit(
      StoryState(
        status: StoryStatus.playing,
        rings: rings,
        ringIndex: ringIndex,
        // Resume where the viewer left off rather than replaying slides
        // they've already seen — what every story app does, and what
        // `hasUnseen` on the rail implicitly promises.
        slideIndex: rings[ringIndex].resumeIndex,
      ),
    );
    _playSlide();
  }

  // -------------------------------------------------------------------
  // Playback
  // -------------------------------------------------------------------

  void _playSlide() {
    _timer?.cancel();
    _elapsed = Duration.zero;
    _resumedAt = DateTime.now();
    _markCurrentViewed();
    _refreshExpiredImage();
    if (!state.paused) _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _resumedAt = DateTime.now();
    _timer = Timer.periodic(_tick, (_) {
      final spent = _elapsed + DateTime.now().difference(_resumedAt);
      final fraction = spent.inMilliseconds / AppConstants.storySegmentDuration.inMilliseconds;
      if (fraction < 1) {
        emit(state.copyWith(progress: fraction));
        return;
      }
      next();
    });
  }

  /// Fire-and-forget: a failed view never interrupts playback, and marking
  /// your own story is a server-side no-op anyway.
  void _markCurrentViewed() {
    final story = state.currentStory;
    if (story == null || story.isOwner || !_viewed.add(story.id)) return;
    _markViewed(story.id);

    if (story.isSeen) return;
    // Flip it locally too, so backing out of the viewer leaves the rail's
    // ring greyed out without waiting on a refetch.
    _replaceStory(story.copyWith(isSeen: true));
  }

  /// A signed image URL lasts 15 minutes. A viewer left open longer than
  /// that (or a rail loaded well before the tap) would show a broken frame,
  /// so re-fetch the story for a fresh one — the only thing that hands out
  /// a new signature.
  Future<void> _refreshExpiredImage() async {
    final story = state.currentStory;
    if (story == null || !story.isImage || !(story.image?.isUrlExpired ?? false)) return;
    final result = await _getStory(story.id);
    if (isClosed) return;
    result.fold((_) {}, (fresh) {
      // Only the image is taken: `isSeen` may have been flipped locally
      // since, and the server's copy of it would undo that.
      if (fresh.image != null) _replaceStory(story.copyWith(image: fresh.image));
    });
  }

  void _replaceStory(StoryEntity story) {
    final rings = [...state.rings];
    final index = rings.indexWhere((r) => r.stories.any((s) => s.id == story.id));
    if (index == -1) return;
    rings[index] = rings[index].withStory(story);
    emit(state.copyWith(rings: rings));
  }

  void next() {
    final ring = state.currentRing;
    if (ring == null) return _finish();

    if (state.slideIndex < ring.stories.length - 1) {
      emit(state.copyWith(slideIndex: state.slideIndex + 1, progress: 0));
      _playSlide();
      return;
    }
    if (state.ringIndex < state.rings.length - 1) {
      final nextRing = state.rings[state.ringIndex + 1];
      emit(state.copyWith(ringIndex: state.ringIndex + 1, slideIndex: nextRing.resumeIndex, progress: 0));
      _playSlide();
      return;
    }
    _finish();
  }

  void previous() {
    if (state.slideIndex > 0) {
      emit(state.copyWith(slideIndex: state.slideIndex - 1, progress: 0));
      _playSlide();
      return;
    }
    if (state.ringIndex > 0) {
      final prev = state.rings[state.ringIndex - 1];
      emit(state.copyWith(ringIndex: state.ringIndex - 1, slideIndex: prev.stories.length - 1, progress: 0));
      _playSlide();
      return;
    }
    // Already on the first slide of the first ring — restart it rather than
    // popping, so a mis-tap on the left edge is recoverable.
    emit(state.copyWith(progress: 0));
    _playSlide();
  }

  /// Holds the current slide — a long-press on the frame, and any sheet or
  /// keyboard opened over it. Idempotent, so overlapping holders are safe.
  void pause() {
    if (state.paused) return;
    _elapsed += DateTime.now().difference(_resumedAt);
    _timer?.cancel();
    emit(state.copyWith(paused: true));
  }

  void resume() {
    if (!state.paused) return;
    emit(state.copyWith(paused: false));
    _startTimer();
  }

  // -------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------

  /// Sends a DM to the story's author. Returns the failure message, or null
  /// on success — the page owns the snackbar.
  ///
  /// The `202` only means accepted: the message itself lands in the
  /// conversation a moment later over the chat socket, so there is nothing
  /// here to wait for beyond the receipt.
  Future<String?> sendReply(String text) async {
    final story = state.currentStory;
    final body = text.trim();
    if (story == null || body.isEmpty || state.replying) return null;

    emit(state.copyWith(replying: true));
    final result = await _replyToStory(
      ReplyToStoryParams(storyId: story.id, text: body, clientId: _clientId()),
    );
    if (isClosed) return null;
    emit(state.copyWith(replying: false));
    return result.fold((failure) => failure.message, (_) => null);
  }

  /// The idempotency key for one reply attempt. A v4-shaped random id built
  /// from [Random] rather than a uuid package (none is a dependency here);
  /// the server only requires 1-64 characters of `[A-Za-z0-9_-]`, and
  /// uniqueness per attempt is all this has to guarantee.
  String _clientId() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final suffix = List.generate(24, (_) => alphabet[_random.nextInt(alphabet.length)]).join();
    return 'c-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-$suffix';
  }

  /// Deletes the slide on screen (owner only) and moves on. Returns the
  /// failure message, or null on success.
  Future<String?> deleteCurrent() async {
    final story = state.currentStory;
    if (story == null || !story.isOwner) return null;

    pause();
    final result = await _deleteStory(story.id);
    if (isClosed) return null;

    return result.fold(
      (failure) {
        resume();
        return failure.message;
      },
      (_) {
        _removeStory(story.id);
        return null;
      },
    );
  }

  /// Drops a deleted slide out of the rings and keeps playing from the same
  /// position, which is now the *next* slide. Finishes when nothing is left.
  void _removeStory(String storyId) {
    final rings = <StoryRingEntity>[];
    var removedFromRing = -1;
    for (var i = 0; i < state.rings.length; i++) {
      final ring = state.rings[i];
      if (!ring.stories.any((s) => s.id == storyId)) {
        rings.add(ring);
        continue;
      }
      removedFromRing = i;
      final trimmed = ring.withoutStory(storyId);
      if (trimmed != null) rings.add(trimmed);
    }
    if (rings.isEmpty) {
      _finish();
      return;
    }

    // The ring the slide came from may have vanished with it, which shifts
    // every later ring down one.
    final ringGone = rings.length < state.rings.length;
    final ringIndex = (ringGone && removedFromRing <= state.ringIndex ? state.ringIndex - 1 : state.ringIndex)
        .clamp(0, rings.length - 1);
    final slideIndex = ringGone && removedFromRing == state.ringIndex
        ? rings[ringIndex].resumeIndex
        : state.slideIndex.clamp(0, rings[ringIndex].stories.length - 1);

    emit(
      state.copyWith(
        rings: rings,
        ringIndex: ringIndex,
        slideIndex: slideIndex,
        progress: 0,
        paused: false,
      ),
    );
    _playSlide();
  }

  void _finish() {
    _timer?.cancel();
    emit(state.copyWith(status: StoryStatus.finished));
  }

  /// Closes the viewer early — the X button. Distinct from running out of
  /// slides only in intent; both land on [StoryStatus.finished], which is
  /// what pops the page. Named `dismiss` rather than `close` because
  /// [Cubit.close] is the disposal hook and means something else entirely.
  void dismiss() => _finish();

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
