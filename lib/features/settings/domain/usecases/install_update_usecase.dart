import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/app_update_repository.dart';

class InstallUpdateParams extends Equatable {
  const InstallUpdateParams(this.filePath);

  final String filePath;

  @override
  List<Object?> get props => [filePath];
}

/// `Right(false)` means "install unknown apps" is still off for Yello — the
/// caller sends the user to that OS screen, not to an error state.
class InstallUpdateUseCase implements UseCase<bool, InstallUpdateParams> {
  InstallUpdateUseCase(this._repository);

  final AppUpdateRepository _repository;

  @override
  Future<Either<Failure, bool>> call(InstallUpdateParams params) => _repository.install(params.filePath);
}
