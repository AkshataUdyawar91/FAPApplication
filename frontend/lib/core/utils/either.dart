/// Functional error handling with Either type
/// Left represents failure, Right represents success
abstract class Either<L, R> {
  const Either();

  bool get isLeft => this is Left<L, R>;
  bool get isRight => this is Right<L, R>;

  L? get left => isLeft ? (this as Left<L, R>).value : null;
  R? get right => isRight ? (this as Right<L, R>).value : null;

  T fold<T>(T Function(L left) leftFn, T Function(R right) rightFn);
}

class Left<L, R> extends Either<L, R> {
  final L value;
  const Left(this.value);

  @override
  T fold<T>(T Function(L left) leftFn, T Function(R right) rightFn) {
    return leftFn(value);
  }
}

class Right<L, R> extends Either<L, R> {
  final R value;
  const Right(this.value);

  @override
  T fold<T>(T Function(L left) leftFn, T Function(R right) rightFn) {
    return rightFn(value);
  }
}
