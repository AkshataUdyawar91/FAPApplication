import 'package:dartz/dartz.dart';
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
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await localDataSource.clearCache();
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      final user = await localDataSource.getCachedUser();
      return Right(user);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
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
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> getSsoAuthorizeUrl(String redirectUri) async {
    try {
      final url = await remoteDataSource.getSsoAuthorizeUrl(redirectUri);
      return Right(url);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
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
      return Left(ServerFailure(e.toString()));
    }
  }
}
