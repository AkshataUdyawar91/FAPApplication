import 'package:equatable/equatable.dart';

/// Base failure class
abstract class Failure extends Equatable {
  final String message;
  
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

/// Server failure (5xx errors)
class ServerFailure extends Failure {
  const ServerFailure([String message = 'Server error occurred']) : super(message);
}

/// Network failure (no internet, timeout)
class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'Network error occurred']) : super(message);
}

/// Authentication failure (401, 403)
class AuthFailure extends Failure {
  const AuthFailure([String message = 'Authentication failed']) : super(message);
}

/// Validation failure (400)
class ValidationFailure extends Failure {
  const ValidationFailure([String message = 'Validation failed']) : super(message);
}

/// Not found failure (404)
class NotFoundFailure extends Failure {
  const NotFoundFailure([String message = 'Resource not found']) : super(message);
}

/// Cache failure
class CacheFailure extends Failure {
  const CacheFailure([String message = 'Cache error occurred']) : super(message);
}
