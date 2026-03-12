import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_local_datasource.dart';
import '../datasources/notification_remote_datasource.dart';
import '../models/device_token_model.dart';
import '../models/notification_preference_model.dart';

/// Implementation of NotificationRepository
class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource remoteDataSource;
  final NotificationLocalDataSource localDataSource;

  NotificationRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, DeviceTokenModel>> registerDeviceToken(
    String token,
    String platform,
  ) async {
    try {
      final deviceToken = await remoteDataSource.registerDeviceToken(
        token,
        platform,
      );
      await localDataSource.saveDeviceTokenId(deviceToken.id);
      return Right(deviceToken);
    } catch (e) {
      return Left(ServerFailure('Failed to register device token: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deregisterDeviceToken(String id) async {
    try {
      await remoteDataSource.deregisterDeviceToken(id);
      await localDataSource.clearDeviceTokenId();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to deregister device token: $e'));
    }
  }

  @override
  Future<String?> getStoredDeviceTokenId() async {
    return await localDataSource.getDeviceTokenId();
  }

  @override
  Future<Either<Failure, NotificationPreferenceResponse>>
      getPreferences() async {
    try {
      final preferences = await remoteDataSource.getPreferences();
      return Right(preferences);
    } catch (e) {
      return Left(ServerFailure('Failed to get preferences: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updatePreference(
    String notificationType,
    bool isPushEnabled,
    bool isEmailEnabled,
  ) async {
    try {
      await remoteDataSource.updatePreference(
        notificationType,
        isPushEnabled,
        isEmailEnabled,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to update preference: $e'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getHistory({
    int page = 1,
    int pageSize = 20,
    String? notificationType,
    String? status,
  }) async {
    try {
      final history = await remoteDataSource.getHistory(
        page: page,
        pageSize: pageSize,
        notificationType: notificationType,
        status: status,
      );
      return Right(history);
    } catch (e) {
      return Left(ServerFailure('Failed to get notification history: $e'));
    }
  }
}
