import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/notification_repository.dart';

/// Use case for deregistering a device token
class DeregisterDeviceTokenUseCase {
  final NotificationRepository repository;

  const DeregisterDeviceTokenUseCase(this.repository);

  Future<Either<Failure, void>> call(String tokenId) async {
    return await repository.deregisterDeviceToken(tokenId);
  }
}
