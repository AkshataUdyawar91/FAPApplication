import 'package:dio/dio.dart';
import '../../../../core/utils/either.dart';
import '../../../../core/error/failures.dart';
import '../../../submission/domain/entities/document_package.dart';
import '../../domain/repositories/approval_repository.dart';
import '../datasources/approval_remote_datasource.dart';

class ApprovalRepositoryImpl implements ApprovalRepository {
  final ApprovalRemoteDataSource remoteDataSource;

  const ApprovalRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, DocumentPackage>> getPackageDetails(
    String packageId,
  ) async {
    try {
      final result = await remoteDataSource.getPackageDetails(packageId);
      return Right(result);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> approvePackage(String packageId) async {
    try {
      await remoteDataSource.approvePackage(packageId);
      return const Right(null);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> rejectPackage(
    String packageId,
    String reason,
  ) async {
    try {
      await remoteDataSource.rejectPackage(packageId, reason);
      return const Right(null);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> requestReupload(
    String packageId,
    List<String> fields,
    String reason,
  ) async {
    try {
      await remoteDataSource.requestReupload(packageId, fields, reason);
      return const Right(null);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<DocumentPackage>>> getPendingPackages() async {
    try {
      final result = await remoteDataSource.getPendingPackages();
      return Right(result);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Failure _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkFailure('Connection timeout');
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401) {
          return const AuthFailure('Unauthorized');
        } else if (statusCode == 403) {
          return const AuthFailure('Forbidden');
        }
        return ServerFailure(
          error.response?.data?['message'] ?? 'Server error',
        );
      case DioExceptionType.cancel:
        return const ServerFailure('Request cancelled');
      default:
        return const NetworkFailure('Network error');
    }
  }
}
