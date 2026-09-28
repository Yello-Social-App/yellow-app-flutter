import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/link_preview_entity.dart';

abstract interface class LinkPreviewRepository {
  /// Reads [url]'s own Open Graph card. A page that answers with something
  /// unreadable is a [Left] — the caller draws no card rather than an empty
  /// one.
  Future<Either<Failure, LinkPreviewEntity>> fetch(String url);
}
