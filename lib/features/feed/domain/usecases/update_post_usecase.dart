import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/post_entity.dart';
import '../repositories/feed_repository.dart';
import 'create_post_usecase.dart' show kPostMaxChars;

class UpdatePostParams extends Equatable {
  const UpdatePostParams({required this.postId, this.content, this.visibility});

  final String postId;
  final String? content;
  final PostVisibility? visibility;

  @override
  List<Object?> get props => [postId, content, visibility];
}

/// Edits a post you own — `PUT /api/v1/posts/{id}`.
class UpdatePostUseCase implements UseCase<PostEntity, UpdatePostParams> {
  UpdatePostUseCase(this._repository);

  final FeedRepository _repository;

  @override
  Future<Either<Failure, PostEntity>> call(UpdatePostParams params) {
    final content = params.content == null
        ? null
        : InputSanitizer.sanitizeText(params.content!, maxLength: kPostMaxChars);
    if (content != null && content.isEmpty) {
      return Future.value(const Left(ValidationFailure('Write something before you save.')));
    }
    return _repository.updatePost(params.postId, content: content, visibility: params.visibility);
  }
}
