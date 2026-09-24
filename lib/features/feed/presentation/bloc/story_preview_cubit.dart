import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/story_entity.dart';
import '../../domain/usecases/story_usecases.dart';

class StoryPreviewState extends Equatable {
  const StoryPreviewState({this.stories = const {}, this.unavailable = const {}});

  /// Resolved stories, keyed by id.
  final Map<String, StoryEntity> stories;

  /// Ids that came back `404` (expired, deleted, blocked, or not visible —
  /// the API deliberately makes all four look the same). Remembered so the
  /// same bubble never asks twice, which is what the contract asks for.
  final Set<String> unavailable;

  @override
  List<Object?> get props => [stories, unavailable];
}

/// A shared, id-keyed cache of stories referenced from chat.
///
/// A story reply carries only a *reference* — chat never stores the story's
/// text or its image — so drawing the preview means fetching the story from
/// yello-api. Several replies in a conversation commonly point at the same
/// story, hence one cache rather than a fetch per bubble.
///
/// Registered as a **lazySingleton**: the cache is the whole point, and it
/// has to outlive any one bubble or conversation.
class StoryPreviewCubit extends Cubit<StoryPreviewState> {
  StoryPreviewCubit(this._getStory) : super(const StoryPreviewState());

  final GetStoryUseCase _getStory;

  /// Ids with a request in flight — without this, a screenful of replies to
  /// the same story fires one request each on first build.
  final Set<String> _inFlight = {};

  /// Fetches [storyId] unless it is already cached, already known missing,
  /// or already being fetched.
  ///
  /// [canLoad] is the caller's own verdict from
  /// `StoryReplyEntity.canStillLoad` — an expired story is a guaranteed
  /// `404` for everyone but its author, so it is marked unavailable without
  /// spending a request on it.
  Future<void> load(String storyId, {bool canLoad = true}) async {
    if (state.stories.containsKey(storyId) || state.unavailable.contains(storyId)) {
      // A signed image URL only lasts 15 minutes; a cached story past that
      // draws a broken thumbnail, so re-fetch it for a fresh signature.
      final cached = state.stories[storyId];
      if (cached == null || !(cached.image?.isUrlExpired ?? false)) return;
    }
    if (!_inFlight.add(storyId)) return;

    if (!canLoad) {
      _inFlight.remove(storyId);
      emit(StoryPreviewState(stories: state.stories, unavailable: {...state.unavailable, storyId}));
      return;
    }

    final result = await _getStory(storyId);
    _inFlight.remove(storyId);
    if (isClosed) return;
    result.fold(
      (_) => emit(StoryPreviewState(stories: state.stories, unavailable: {...state.unavailable, storyId})),
      (story) => emit(
        StoryPreviewState(stories: {...state.stories, storyId: story}, unavailable: state.unavailable),
      ),
    );
  }
}
