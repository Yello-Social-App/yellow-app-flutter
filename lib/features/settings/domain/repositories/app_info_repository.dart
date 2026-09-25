import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/app_build_info.dart';

abstract interface class AppInfoRepository {
  /// The build installed on this device. Never hits the network, so it
  /// resolves with the radio off.
  Future<Either<Failure, AppBuildInfo>> getBuildInfo();
}
