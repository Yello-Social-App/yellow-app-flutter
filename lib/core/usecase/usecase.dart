import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../error/failures.dart';

/// A single application action, callable as `usecase(params)` thanks to
/// `call`. `Result` is the success value; `Params` is a single object
/// bundling the input arguments (use [NoParams] when there are none).
abstract interface class UseCase<Result, Params> {
  Future<Either<Failure, Result>> call(Params params);
}

/// Marker for use cases that take no arguments.
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
