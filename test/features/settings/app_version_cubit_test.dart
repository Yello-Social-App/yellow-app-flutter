import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/error/failures.dart';
import 'package:yello_social_app/core/usecase/usecase.dart';
import 'package:yello_social_app/features/settings/domain/entities/app_build_info.dart';
import 'package:yello_social_app/features/settings/domain/usecases/get_app_build_info_usecase.dart';
import 'package:yello_social_app/features/settings/presentation/bloc/app_version_cubit.dart';

class _MockGetAppBuildInfo extends Mock implements GetAppBuildInfoUseCase {}

const _info = AppBuildInfo(
  appName: 'Yello',
  version: '1.0.0',
  buildNumber: '1',
  packageName: 'com.hushstack.yello',
  platform: 'Android',
  osVersion: 'Android 15 (SDK 35)',
  deviceModel: 'Google Pixel 7',
);

void main() {
  setUpAll(() => registerFallbackValue(const NoParams()));

  late _MockGetAppBuildInfo getBuildInfo;

  setUp(() => getBuildInfo = _MockGetAppBuildInfo());

  AppVersionCubit build() => AppVersionCubit(getBuildInfo: getBuildInfo);

  test('load emits loaded with the build info', () async {
    when(() => getBuildInfo(any())).thenAnswer((_) async => const Right(_info));

    final cubit = build();
    await cubit.load();

    expect(cubit.state.status, AppVersionStatus.loaded);
    expect(cubit.state.info, _info);
    expect(cubit.state.errorMessage, isNull);
    await cubit.close();
  });

  test('load emits error with the failure message', () async {
    when(() => getBuildInfo(any())).thenAnswer((_) async => const Left(CacheFailure('nope')));

    final cubit = build();
    await cubit.load();

    expect(cubit.state.status, AppVersionStatus.error);
    expect(cubit.state.info, isNull);
    expect(cubit.state.errorMessage, 'nope');
    await cubit.close();
  });

  test('a second load while the first is in flight is ignored', () async {
    final gate = Completer<Either<Failure, AppBuildInfo>>();
    when(() => getBuildInfo(any())).thenAnswer((_) => gate.future);

    final cubit = build();
    final first = cubit.load();
    final second = cubit.load();

    gate.complete(const Right(_info));
    await Future.wait([first, second]);

    verify(() => getBuildInfo(any())).called(1);
    expect(cubit.state.status, AppVersionStatus.loaded);
    await cubit.close();
  });

  test('versionLabel reads as the stores write it', () {
    expect(_info.versionLabel, '1.0.0 (1)');
    expect(
      const AppBuildInfo(
        appName: 'Yello',
        version: '1.0.0',
        buildNumber: '',
        packageName: 'com.hushstack.yello',
        platform: 'iOS',
      ).versionLabel,
      '1.0.0',
    );
  });
}
