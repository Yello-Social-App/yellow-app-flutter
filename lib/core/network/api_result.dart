import 'package:dartz/dartz.dart';

import '../error/failures.dart';

/// The standard repository return shape: either a domain [Failure] or the
/// successful value. A typedef (not a new class) so it composes directly
/// with `dartz`'s `Either` combinators (`.fold`, `.map`, etc.) that use
/// cases and Cubits already rely on.
typedef ApiResult<T> = Either<Failure, T>;

/// Small ergonomic helpers on top of `dartz`'s `Either` for the handful of
/// patterns repeated across every repository implementation.
extension ApiResultX<T> on ApiResult<T> {
  R when<R>({
    required R Function(Failure failure) failure,
    required R Function(T data) success,
  }) =>
      fold(failure, success);

  T? get dataOrNull => fold((_) => null, (r) => r);
  Failure? get failureOrNull => fold((l) => l, (_) => null);
  bool get isSuccess => isRight();
}
