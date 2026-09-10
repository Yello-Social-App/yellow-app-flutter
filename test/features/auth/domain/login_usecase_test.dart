import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/error/failures.dart';
import 'package:yello_social_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:yello_social_app/features/auth/domain/usecases/login_usecase.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;
  late LoginUseCase useCase;

  setUp(() {
    repository = _MockAuthRepository();
    useCase = LoginUseCase(repository);
  });

  test('rejects an invalid email without calling the repository', () async {
    final result = await useCase(const LoginParams(email: 'not-an-email', password: 'irrelevant'));

    expect(result, isA<Left<Failure, void>>());
    expect(result.fold((l) => l, (r) => null), isA<ValidationFailure>());
    verifyNever(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
        rememberMe: any(named: 'rememberMe'),
      ),
    );
  });

  test('rejects an empty password without calling the repository', () async {
    final result = await useCase(const LoginParams(email: 'a@example.com', password: ''));

    expect(result.fold((l) => l, (r) => null), isA<ValidationFailure>());
    verifyNever(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
        rememberMe: any(named: 'rememberMe'),
      ),
    );
  });

  test('trims the email and delegates to the repository when valid', () async {
    when(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
        rememberMe: any(named: 'rememberMe'),
      ),
    ).thenAnswer((_) async => const Right(null));

    final result = await useCase(const LoginParams(email: '  a@example.com  ', password: 'password123456'));

    expect(result.isRight(), isTrue);
    verify(() => repository.login(email: 'a@example.com', password: 'password123456', rememberMe: true))
        .called(1);
  });

  test('passes rememberMe: false through to the repository when declined', () async {
    when(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
        rememberMe: any(named: 'rememberMe'),
      ),
    ).thenAnswer((_) async => const Right(null));

    final result = await useCase(
      const LoginParams(email: 'a@example.com', password: 'password123456', rememberMe: false),
    );

    expect(result.isRight(), isTrue);
    verify(() => repository.login(email: 'a@example.com', password: 'password123456', rememberMe: false))
        .called(1);
  });
}
