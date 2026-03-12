import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../data/models/device_token_model.dart';
import '../../data/models/notification_preference_model.dart';

/// Abstract repository for notification operations
abstract class NotificationRepository {
  /// Register a device token and store the ID locally
  Future<Either<Failure, DeviceTokenModel>> registerDeviceToken(
    String token,
    String platform,
  );

  /// Deregister a device token and clear local storage
  Future<Either<Failure, void>> deregisterDeviceToken(String id);

  /// Get the locally stored device token ID
  Future<String?> getStoredDeviceTokenId();

  /// Get user notification preferences
  Future<Either<Failure, NotificationPreferenceResponse>> getPreferences();

  /// Update a notification preference
  Future<Either<Failure, void>> updatePreference(
    String notificationType,
    bool isPushEnabled,
    bool isEmailEnabled,
  );

  /// Get notification history
  Future<Either<Failure, Map<String, dynamic>>> getHistory({
    int page = 1,
    int pageSize = 20,
    String? notificationType,
    String? status,
  });
}
