import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/post_entity.dart';
import '../repositories/feed_repository.dart';
import 'create_post_usecase.dart' show kPostMaxChars;

class UpdatePostParams extends Equatable {
  const UpdatePostParams({
    required this.postId,
    this.content,
    this.visibility,
    this.images = const [],
    this.removeImageIds = const [],
  });

  final String postId;
  final String? content;
  final PostVisibility? visibility;

  /// New photos to append to the post. The backend caps a post's total image
  /// count, so a call that would exceed it is rejected server-side rather
  /// than silently truncated.
  final List<File> images;

  /// `PostEntity.images`' `id`s to drop. Removals apply to the post's
  /// *existing* images, so an id here never refers to one of [images].
  final List<String> removeImageIds;

  @override
  List<Object?> get props => [postId, content, visibility, images, removeImageIds];
}

/// Edits a post you own — `PUT /posts/{id}`.
class UpdatePostUseCase implements UseCase<PostEntity, UpdatePostParams> {
  UpdatePostUseCase(this._repository);

  final FeedRepository _repository;

  @override
  Future<Either<Failure, PostEntity>> call(UpdatePostParams params) {
    final content = params.content == null
        ? null
        : InputSanitizer.sanitizeText(params.content!, maxLength: kPostMaxChars);
    // An empty caption is only a problem when the post would be left with
    // nothing at all — a photo-only post is valid, so let a blank caption
    // through whenever images survive the edit or new ones are attached.
    final keepsImages = params.images.isNotEmpty;
    if (content != null && content.isEmpty && !keepsImages) {
      return Future.value(const Left(ValidationFailure('Write something before you save.')));
    }
    return _repository.updatePost(
      params.postId,
      content: content,
      visibility: params.visibility,
      images: params.images,
      removeImageIds: params.removeImageIds,
    );
  }
}
