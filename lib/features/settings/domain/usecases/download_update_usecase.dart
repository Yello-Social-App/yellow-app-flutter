import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/app_update.dart';
import '../repositories/app_update_repository.dart';

class DownloadUpdateParams extends Equatable {
  const DownloadUpdateParams({required this.update, this.onProgress});

  final AppUpdate update;

  /// 0.0–1.0, or never called when the server sends no content length.
  final void Function(double progress)? onProgress;

  @override
  List<Object?> get props => [update];
}

/// Resolves with the downloaded APK's local path.
class DownloadUpdateUseCase implements UseCase<String, DownloadUpdateParams> {
  DownloadUpdateUseCase(this._repository);

  final AppUpdateRepository _repository;

  @override
  Future<Either<Failure, String>> call(DownloadUpdateParams params) =>
      _repository.download(params.update, onProgress: params.onProgress);
}
