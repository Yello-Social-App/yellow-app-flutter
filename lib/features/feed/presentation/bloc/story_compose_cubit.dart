import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/story_entity.dart';
import '../../domain/usecases/story_usecases.dart';

enum StoryComposeStatus { editing, posting, posted, error }

class StoryComposeState extends Equatable {
  const StoryComposeState({
    this.status = StoryComposeStatus.editing,
    this.text = '',
    this.background = StoryBackground.cover0,
    this.image,
    this.visibility = StoryVisibility.friends,
    this.errorMessage,
  });

  final StoryComposeStatus status;

  /// The story itself in text mode, the caption in photo mode.
  final String text;

  /// Only used in text mode — the server ignores it on an `IMAGE` story.
  final StoryBackground background;

  /// Non-null switches the composer to photo mode.
  final File? image;
  final StoryVisibility visibility;
  final String? errorMessage;

  bool get isPhoto => image != null;
  bool get isPosting => status == StoryComposeStatus.posting;

  /// A text story needs words; a photo story needs only the photo, since
  /// its caption is optional.
  bool get canPost => !isPosting && (isPhoto || text.trim().isNotEmpty);

  StoryComposeState copyWith({
    StoryComposeStatus? status,
    String? text,
    StoryBackground? background,
    File? image,
    bool clearImage = false,
    StoryVisibility? visibility,
    String? errorMessage,
  }) {
    return StoryComposeState(
      status: status ?? this.status,
      text: text ?? this.text,
      background: background ?? this.background,
      image: clearImage ? null : (image ?? this.image),
      visibility: visibility ?? this.visibility,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, text, background, image?.path, visibility, errorMessage];
}

/// "Add to your story" — one screen that posts either kind of story, since
/// `POST /stories` is one path with two request bodies.
class StoryComposeCubit extends Cubit<StoryComposeState> {
  StoryComposeCubit(this._createStory) : super(const StoryComposeState());

  final CreateStoryUseCase _createStory;

  /// The story the last successful post created, so the caller can drop it
  /// straight into "Your story" — the spec is explicit that no follow-up
  /// `GET /stories/me` is needed.
  StoryEntity? posted;

  void setText(String value) => emit(state.copyWith(text: value));

  void setBackground(StoryBackground background) => emit(state.copyWith(background: background));

  void setVisibility(StoryVisibility visibility) => emit(state.copyWith(visibility: visibility));

  void setImage(File image) => emit(state.copyWith(image: image));

  /// Back to text mode. The caption typed under the photo is kept — it is
  /// the same field either way, and re-typing it would be a surprise.
  void clearImage() => emit(state.copyWith(clearImage: true));

  Future<bool> post() async {
    if (!state.canPost) return false;
    emit(state.copyWith(status: StoryComposeStatus.posting));

    final text = state.text.trim();
    final result = await _createStory(
      CreateStoryParams(
        text: text.isEmpty ? null : text,
        // Sent only in text mode: the server ignores `background` on an
        // image story, and leaving it out keeps the multipart body honest.
        background: state.isPhoto ? null : state.background,
        image: state.image,
        visibility: state.visibility,
      ),
    );
    if (isClosed) return false;

    return result.fold(
      (failure) {
        emit(state.copyWith(status: StoryComposeStatus.error, errorMessage: failure.message));
        return false;
      },
      (story) {
        posted = story;
        emit(state.copyWith(status: StoryComposeStatus.posted));
        return true;
      },
    );
  }
}
