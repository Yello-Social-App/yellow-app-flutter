import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/post_entity.dart';
import '../../domain/usecases/create_post_usecase.dart';

enum CreatePostStatus { editing, publishing, published, error }

/// The three pre-publish checklist prompts from the mockup's "BEFORE YOU
/// POST" panel. Purely a client-side mindful-posting nudge — the backend
/// has no concept of it, so it only gates the PUBLISH button locally.
const List<String> kPrePublishChecks = [
  'The words say what I actually mean.',
  'Everyone in the photo is fine with being here.',
  "I'd still be glad this is on my profile next month.",
];

/// Suggested tags from the mockup's "TAGS" panel. The backend has no tag
/// field on `PostResponse`, so selected tags are appended to the post
/// content as hashtags on publish (see [CreatePostCubit.publish]) rather
/// than dropped.
const List<String> kTagPool = ['light', 'concrete', 'site', 'notes', 'process'];

class CreatePostState extends Equatable {
  const CreatePostState({
    this.status = CreatePostStatus.editing,
    this.text = '',
    this.pickedTags = const ['light'],
    this.visibility = PostVisibility.public,
    this.checked = const {},
    this.errorMessage,
    this.publishedPost,
    this.images = const [],
  });

  final CreatePostStatus status;
  final String text;
  final List<String> pickedTags;
  final PostVisibility visibility;
  final Set<int> checked;
  final String? errorMessage;
  final PostEntity? publishedPost;

  /// Picked from the device gallery — attached to the post on publish, in
  /// selection order. Capped at [AppConstants.postMaxImages].
  final List<File> images;

  int get charCount => text.trim().length;
  bool get isShort => charCount > 0 && charCount < AppConstants.postShortLengthThreshold;
  bool get allChecked => checked.length == kPrePublishChecks.length;
  bool get canPublish => charCount > 0 && allChecked && status != CreatePostStatus.publishing;

  CreatePostState copyWith({
    CreatePostStatus? status,
    String? text,
    List<String>? pickedTags,
    PostVisibility? visibility,
    Set<int>? checked,
    String? errorMessage,
    PostEntity? publishedPost,
    List<File>? images,
  }) {
    return CreatePostState(
      status: status ?? this.status,
      text: text ?? this.text,
      pickedTags: pickedTags ?? this.pickedTags,
      visibility: visibility ?? this.visibility,
      checked: checked ?? this.checked,
      errorMessage: errorMessage,
      publishedPost: publishedPost ?? this.publishedPost,
      images: images ?? this.images,
    );
  }

  @override
  List<Object?> get props => [status, text, pickedTags, visibility, checked, errorMessage, images];
}

class CreatePostCubit extends Cubit<CreatePostState> {
  CreatePostCubit(this._createPost) : super(const CreatePostState());

  final CreatePostUseCase _createPost;

  void setText(String value) => emit(state.copyWith(text: value));

  void setVisibility(PostVisibility visibility) => emit(state.copyWith(visibility: visibility));

  void toggleTag(String tag) {
    final tags = [...state.pickedTags];
    tags.contains(tag) ? tags.remove(tag) : tags.add(tag);
    emit(state.copyWith(pickedTags: tags));
  }

  void toggleCheck(int index) {
    final checked = {...state.checked};
    checked.contains(index) ? checked.remove(index) : checked.add(index);
    emit(state.copyWith(checked: checked));
  }

  /// Appends newly-picked photos to the existing selection, in order,
  /// silently capping the total at [AppConstants.postMaxImages] (the picker
  /// UI already caps how many it asks for, so this is just a backstop).
  void addImages(List<File> files) {
    final combined = [...state.images, ...files];
    emit(state.copyWith(images: combined.take(AppConstants.postMaxImages).toList()));
  }

  void removeImageAt(int index) {
    final images = [...state.images]..removeAt(index);
    emit(state.copyWith(images: images));
  }

  Future<void> publish() async {
    if (!state.canPublish) return;
    emit(state.copyWith(status: CreatePostStatus.publishing));

    final hashtags = state.pickedTags.map((t) => '#$t').join(' ');
    final content = hashtags.isEmpty ? state.text : '${state.text}\n\n$hashtags';

    final result = await _createPost(
      CreatePostParams(content: content, visibility: state.visibility, images: state.images),
    );
    result.fold(
      (failure) =>
          emit(state.copyWith(status: CreatePostStatus.error, errorMessage: failure.message)),
      (post) => emit(state.copyWith(status: CreatePostStatus.published, publishedPost: post)),
    );
  }
}
