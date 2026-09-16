import 'package:dartz/dartz.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/logger.dart';
import '../../../notification/domain/repositories/notification_repository.dart';
import '../repositories/auth_repository.dart';

class LogoutUseCase implements UseCase<void, NoParams> {
  LogoutUseCase(this._repository, this._notificationRepository, this._secureStorage);

  final AuthRepository _repository;
  final NotificationRepository _notificationRepository;
  final SecureStorageService _secureStorage;

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    // `yello-notify`'s documented client flow: unregister this device's
    // push token *before* the yello-api token it's tied to gets discarded —
    // that endpoint still needs a valid bearer token to authenticate the
    // call. Best-effort: a failure here must never block the actual
    // sign-out the user asked for (offline logout, an already-expired
    // token, or simply no push token ever having been registered — there's
    // no push SDK wired up yet, so this is a no-op today).
    final token = await _secureStorage.read(AppConstants.secureKeyPushToken);
    if (token != null) {
      final result = await _notificationRepository.unregisterDevice(token);
      result.fold(
        (failure) => appLogger.w('LogoutUseCase: unregisterDevice failed — ${failure.message}'),
        (_) {},
      );
    }
    return _repository.logout();
  }
}
