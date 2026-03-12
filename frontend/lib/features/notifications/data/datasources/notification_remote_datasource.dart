import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/device_token_model.dart';
import '../models/notification_preference_model.dart';

/// Remote data source for notification API calls
abstract class NotificationRemoteDataSource {
  /// Register a device token with the backend
  Future<DeviceTokenModel> registerDeviceToken(String token, String platform);

  /// Deregister a device token by ID
  Future<void> deregisterDeviceToken(String id);

  /// Get user notification preferences
  Future<NotificationPreferenceResponse> getPreferences();

  /// Update a notification preference
  Future<void> updatePreference(
    String notificationType,
    bool isPushEnabled,
    bool isEmailEnabled,
  );

  /// Get notification history with optional filters
  Future<Map<String, dynamic>> getHistory({
    int page = 1,
    int pageSize = 20,
    String? notificationType,
    String? status,
  });
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final Dio dio;

  NotificationRemoteDataSourceImpl(this.dio);

  @override
  Future<DeviceTokenModel> registerDeviceToken(
    String token,
    String platform,
  ) async {
    try {
      final response = await dio.post(
        ApiConstants.deviceTokens,
        data: {
          'token': token,
          'platform': platform,
        },
      );

      return DeviceTokenModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to register device token: ${e.message}');
    }
  }

  @override
  Future<void> deregisterDeviceToken(String id) async {
    try {
      await dio.delete(ApiConstants.deregisterDeviceToken(id));
    } on DioException catch (e) {
      throw Exception('Failed to deregister device token: ${e.message}');
    }
  }

  @override
  Future<NotificationPreferenceResponse> getPreferences() async {
    try {
      final response = await dio.get(ApiConstants.notificationPreferences);

      return NotificationPreferenceResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw Exception('Failed to get notification preferences: ${e.message}');
    }
  }

  @override
  Future<void> updatePreference(
    String notificationType,
    bool isPushEnabled,
    bool isEmailEnabled,
  ) async {
    try {
      await dio.put(
        ApiConstants.notificationPreferences,
        data: {
          'notificationType': notificationType,
          'isPushEnabled': isPushEnabled,
          'isEmailEnabled': isEmailEnabled,
        },
      );
    } on DioException catch (e) {
      throw Exception('Failed to update notification preference: ${e.message}');
    }
  }

  @override
  Future<Map<String, dynamic>> getHistory({
    int page = 1,
    int pageSize = 20,
    String? notificationType,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
      };
      if (notificationType != null) {
        queryParams['notificationType'] = notificationType;
      }
      if (status != null) {
        queryParams['status'] = status;
      }

      final response = await dio.get(
        ApiConstants.notificationHistory,
        queryParameters: queryParams,
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('Failed to get notification history: ${e.message}');
    }
  }
}
