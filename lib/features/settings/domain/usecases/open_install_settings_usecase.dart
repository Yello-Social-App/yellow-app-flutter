import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/app_update_repository.dart';

class OpenInstallSettingsUseCase implements UseCase<void, NoParams> {
  OpenInstallSettingsUseCase(this._repository);

  final AppUpdateRepository _repository;

  @override
  Future<Either<Failure, void>> call(NoParams params) => _repository.openInstallSettings();
}
