import 'package:dio/dio.dart';
import '../../../../core/utils/either.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/kpi_dashboard.dart';
import '../../domain/entities/state_roi.dart';
import '../../domain/entities/campaign_breakdown.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../datasources/analytics_remote_datasource.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final AnalyticsRemoteDataSource remoteDataSource;

  const AnalyticsRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, KPIDashboard>> getKPIs() async {
    try {
      final result = await remoteDataSource.getKPIs();
      return Right(result);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<StateROI>>> getStateROI() async {
    try {
      final result = await remoteDataSource.getStateROI();
      return Right(result);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CampaignBreakdown>>> getCampaignBreakdown() async {
    try {
      final result = await remoteDataSource.getCampaignBreakdown();
      return Right(result);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> exportAnalytics() async {
    try {
      final result = await remoteDataSource.exportAnalytics();
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
