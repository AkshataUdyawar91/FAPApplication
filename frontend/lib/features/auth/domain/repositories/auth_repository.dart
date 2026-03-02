import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user.dart';

/// Authentication repository interface
abstract class AuthRepository {
  /// Login with email and password
  Future<Either<Failure, User>> login(String email, String password);

  /// Logout current user
  Future<Either<Failure, void>> logout();

  /// Get current user from local storage
  Future<Either<Failure, User?>> getCurrentUser();

  /// Refresh authentication token
  Future<Either<Failure, void>> refreshToken();
}
