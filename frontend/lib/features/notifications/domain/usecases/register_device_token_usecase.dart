import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../data/models/device_token_model.dart';
import '../repositories/notification_repository.dart';

/// Use case for registering a device token
class RegisterDeviceTokenUseCase {
  final NotificationRepository repository;

  const RegisterDeviceTokenUseCase(this.repository);

  Future<Either<Failure, DeviceTokenModel>> call(
    String token,
    String platform,
  ) async {
    return await repository.registerDeviceToken(token, platform);
  }
}
