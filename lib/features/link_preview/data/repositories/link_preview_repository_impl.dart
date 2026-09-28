import 'package:dartz/dartz.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/link_preview_entity.dart';
import '../../domain/repositories/link_preview_repository.dart';
import '../datasources/link_preview_remote_datasource.dart';

class LinkPreviewRepositoryImpl implements LinkPreviewRepository {
  LinkPreviewRepositoryImpl(this._remote, this._networkInfo);

  final LinkPreviewRemoteDataSource _remote;
  final NetworkInfo _networkInfo;

  @override
  Future<Either<Failure, LinkPreviewEntity>> fetch(String url) async {
    if (!await _networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right((await _remote.fetch(url)).toEntity());
    } on AppException catch (e) {
      return Left(ErrorHandler.toFailure(e));
    } catch (e) {
      // A page's markup is not input this app controls, so a parse that goes
      // wrong is a missing card, never a crash (OWASP A10).
      return Left(UnknownFailure(e.toString()));
    }
  }
}
