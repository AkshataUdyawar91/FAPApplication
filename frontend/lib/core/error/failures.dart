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
  const ServerFailure([super.message = 'Server error occurred']);
}

/// Network failure (no internet, timeout)
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network error occurred']);
}

/// Authentication failure (401, 403)
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed']);
}

/// Validation failure (400)
class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Validation failed']);
}

/// Not found failure (404)
class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Resource not found']);
}

/// Cache failure
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Cache error occurred']);
}
