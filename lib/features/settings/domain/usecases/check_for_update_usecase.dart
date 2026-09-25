import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/app_update.dart';
import '../repositories/app_update_repository.dart';

/// `Right(null)` means the check succeeded and this build is current.
class CheckForUpdateUseCase implements UseCase<AppUpdate?, NoParams> {
  CheckForUpdateUseCase(this._repository);

  final AppUpdateRepository _repository;

  @override
  Future<Either<Failure, AppUpdate?>> call(NoParams params) => _repository.checkForUpdate();
}
