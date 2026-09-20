import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/comment_entity.dart';
import '../repositories/feed_repository.dart';
import 'add_comment_usecase.dart' show kCommentMaxChars;

class EditCommentParams extends Equatable {
  const EditCommentParams({required this.commentId, required this.text});
  final String commentId;
  final String text;

  @override
  List<Object?> get props => [commentId, text];
}

/// Rewrites one of your own comments — `PUT /comments/{id}`. Works for a
/// comment on a feed post and on a community post alike: both live on the
/// same `/comments/{id}` resource once created.
class EditCommentUseCase implements UseCase<CommentEntity, EditCommentParams> {
  EditCommentUseCase(this._repository);

  final FeedRepository _repository;

  @override
  Future<Either<Failure, CommentEntity>> call(EditCommentParams params) {
    final clean = InputSanitizer.sanitizeText(params.text, maxLength: kCommentMaxChars);
    if (clean.isEmpty) {
      return Future.value(const Left(ValidationFailure('Comment cannot be empty.')));
    }
    return _repository.editComment(params.commentId, clean);
  }
}
