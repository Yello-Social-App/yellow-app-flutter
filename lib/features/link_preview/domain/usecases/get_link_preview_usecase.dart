import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/link_preview_entity.dart';
import '../repositories/link_preview_repository.dart';

/// Reads the card a linked page advertises for itself. Takes the URL as its
/// params — there is nothing else to pass.
class GetLinkPreviewUseCase implements UseCase<LinkPreviewEntity, String> {
  GetLinkPreviewUseCase(this._repository);

  final LinkPreviewRepository _repository;

  @override
  Future<Either<Failure, LinkPreviewEntity>> call(String url) => _repository.fetch(url);
}
