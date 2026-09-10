import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/post_entity.dart';
import '../repositories/feed_repository.dart';

/// `UpdatePostRequest.content` / the create-post `content` query param are
/// capped at 5000 chars by the backend.
const int kPostMaxChars = 5000;

class CreatePostParams extends Equatable {
  const CreatePostParams({required this.content, required this.visibility, this.images = const []});

  final String content;
  final PostVisibility visibility;
  final List<File> images;

  @override
  List<Object?> get props => [content, visibility, images];
}

class CreatePostUseCase implements UseCase<PostEntity, CreatePostParams> {
  CreatePostUseCase(this._repository);

  final FeedRepository _repository;

  @override
  Future<Either<Failure, PostEntity>> call(CreatePostParams params) {
    final clean = InputSanitizer.sanitizeText(params.content, maxLength: kPostMaxChars);
    if (clean.isEmpty) {
      return Future.value(const Left(ValidationFailure('Write something before you post.')));
    }
    return _repository.createPost(content: clean, visibility: params.visibility, images: params.images);
  }
}
