import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/comment_entity.dart';
import '../repositories/feed_repository.dart';

/// `CreateCommentRequest.content` is capped at 2000 chars by the backend.
const int kCommentMaxChars = 2000;

class AddCommentParams extends Equatable {
  const AddCommentParams({required this.postId, required this.text, this.parentCommentId});
  final String postId;
  final String text;
  final String? parentCommentId;

  @override
  List<Object?> get props => [postId, text, parentCommentId];
}

class AddCommentUseCase implements UseCase<CommentEntity, AddCommentParams> {
  AddCommentUseCase(this._repository);

  final FeedRepository _repository;

  @override
  Future<Either<Failure, CommentEntity>> call(AddCommentParams params) {
    final clean = InputSanitizer.sanitizeText(params.text, maxLength: kCommentMaxChars);
    if (clean.isEmpty) {
      return Future.value(const Left(ValidationFailure('Comment cannot be empty.')));
    }
    return _repository.addComment(params.postId, clean, parentCommentId: params.parentCommentId);
  }
}
