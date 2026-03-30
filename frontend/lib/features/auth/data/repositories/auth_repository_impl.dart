import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

/// Implementation of AuthRepository
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  /// Maps exceptions to user-friendly Failure subtypes.
  Failure _mapException(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return const NetworkFailure('No internet connection. Check your network and try again.');
        case DioExceptionType.badResponse:
          final statusCode = e.response?.statusCode;
          final serverMsg = e.response?.data?['message']?.toString();
          if (statusCode == 401) {
            return AuthFailure(serverMsg ?? 'Invalid email or password.');
          }
          if (statusCode == 403) {
            return const AuthFailure('Access denied. Contact your administrator.');
          }
          if (statusCode == 404) return const NotFoundFailure();
          return ServerFailure(serverMsg ?? 'Something went wrong. Please try again.');
        default:
          return const NetworkFailure('No internet connection. Check your network and try again.');
      }
    }
    return const ServerFailure('Something went wrong. Please try again.');
  }

  @override
  Future<Either<Failure, (User, String)>> login(String email, String password) async {
    try {
      final response = await remoteDataSource.login(email, password);

      // Cache user and token — wrapped separately so a storage failure
      // doesn't prevent the user from proceeding after a successful login.
      try {
        await localDataSource.cacheUser(response.user);
        await localDataSource.saveTokens(
          response.token,
          '', // Backend uses token refresh endpoint, no separate refresh token
        );
      } catch (storageError) {
        // Log but don't fail — the user authenticated successfully.
        // On web release builds, secure storage can occasionally throw.
        print('[AuthRepository] Warning: failed to cache credentials: $storageError');
      }

      return Right((response.user, response.token));
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await localDataSource.clearCache();
      return const Right(null);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      final user = await localDataSource.getCachedUser();
      return Right(user);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, void>> refreshToken() async {
    try {
      final refreshToken = await localDataSource.getRefreshToken();
      if (refreshToken == null) {
        return const Left(CacheFailure('No refresh token found'));
      }

      await remoteDataSource.refreshToken(refreshToken);
      return const Right(null);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, String>> getSsoAuthorizeUrl(String redirectUri) async {
    try {
      final url = await remoteDataSource.getSsoAuthorizeUrl(redirectUri);
      return Right(url);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, (User, String)>> ssoLogin(String code, String redirectUri) async {
    try {
      final response = await remoteDataSource.ssoLogin(code, redirectUri);

      // Cache user and token — wrapped separately so a storage failure
      // doesn't prevent the user from proceeding.
      try {
        await localDataSource.cacheUser(response.user);
        await localDataSource.saveTokens(response.token, '');
      } catch (storageError) {
        print('[AuthRepository] Warning: failed to cache SSO credentials: $storageError');
      }

      return Right((response.user, response.token));
    } catch (e) {
      return Left(_mapException(e));
    }
  }
}
