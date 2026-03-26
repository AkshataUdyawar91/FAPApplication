import 'package:dartz/dartz.dart';

import 'failures.dart';

/// Wraps retry logic for failed operations.
///
/// Executes the provided callback exactly once per [execute] call
/// and returns the result.
class RetryHandler {
  /// Executes the [operation] callback exactly once.
  ///
  /// Returns the result of the operation, or a [ServerFailure]
  /// if an unexpected exception occurs during execution.
  static Future<Either<Failure, T>> execute<T>(
    Future<Either<Failure, T>> Function() operation,
  ) async {
    try {
      return await operation();
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
