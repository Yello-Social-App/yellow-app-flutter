import 'package:dartz/dartz.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/app_build_info.dart';
import '../../domain/repositories/app_info_repository.dart';
import '../datasources/app_info_local_datasource.dart';

class AppInfoRepositoryImpl implements AppInfoRepository {
  AppInfoRepositoryImpl(this._local);

  final AppInfoLocalDataSource _local;

  /// No `NetworkInfo` gate, unlike the remote-backed repositories: this data
  /// comes off the device and must still resolve offline.
  @override
  Future<Either<Failure, AppBuildInfo>> getBuildInfo() async {
    try {
      return Right(await _local.getBuildInfo());
    } on AppException catch (e) {
      return Left(ErrorHandler.toFailure(e));
    } catch (_) {
      return const Left(CacheFailure("Could not read this build's details."));
    }
  }
}
