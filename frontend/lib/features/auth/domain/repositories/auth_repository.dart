import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user.dart';

/// Authentication repository interface
abstract class AuthRepository {
  /// Login with email and password.
  /// Returns the [User] and the JWT token string.
  Future<Either<Failure, (User, String)>> login(String email, String password);

  /// Logout current user
  Future<Either<Failure, void>> logout();

  /// Get current user from local storage
  Future<Either<Failure, User?>> getCurrentUser();

  /// Refresh authentication token
  Future<Either<Failure, void>> refreshToken();

  /// Get Azure AD SSO authorization URL
  Future<Either<Failure, String>> getSsoAuthorizeUrl(String redirectUri);

  /// Login via Azure AD SSO using authorization code.
  /// Returns the [User] and the JWT token string.
  Future<Either<Failure, (User, String)>> ssoLogin(String code, String redirectUri);
}
