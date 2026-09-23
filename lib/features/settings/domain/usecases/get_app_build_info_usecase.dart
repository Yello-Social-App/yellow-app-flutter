import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/app_build_info.dart';
import '../repositories/app_info_repository.dart';

class GetAppBuildInfoUseCase implements UseCase<AppBuildInfo, NoParams> {
  GetAppBuildInfoUseCase(this._repository);

  final AppInfoRepository _repository;

  @override
  Future<Either<Failure, AppBuildInfo>> call(NoParams params) => _repository.getBuildInfo();
}
