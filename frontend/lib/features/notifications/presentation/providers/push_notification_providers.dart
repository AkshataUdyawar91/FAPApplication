import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/notification_local_datasource.dart';
import '../../data/datasources/notification_remote_datasource.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/usecases/deregister_device_token_usecase.dart';
import '../../domain/usecases/register_device_token_usecase.dart';
import '../services/push_notification_service.dart';
import 'notification_preferences_notifier.dart';

// Data sources
final notificationRemoteDataSourceProvider =
    Provider<NotificationRemoteDataSource>((ref) {
  return NotificationRemoteDataSourceImpl(ref.watch(dioClientProvider));
});

final notificationLocalDataSourceProvider =
    Provider<NotificationLocalDataSource>((ref) {
  return NotificationLocalDataSourceImpl(ref.watch(secureStorageProvider));
});

// Repository
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(
    remoteDataSource: ref.watch(notificationRemoteDataSourceProvider),
    localDataSource: ref.watch(notificationLocalDataSourceProvider),
  );
});

// Use cases
final registerDeviceTokenUseCaseProvider =
    Provider<RegisterDeviceTokenUseCase>((ref) {
  return RegisterDeviceTokenUseCase(ref.watch(notificationRepositoryProvider));
});

final deregisterDeviceTokenUseCaseProvider =
    Provider<DeregisterDeviceTokenUseCase>((ref) {
  return DeregisterDeviceTokenUseCase(
    ref.watch(notificationRepositoryProvider),
  );
});

// Push notification service (abstraction for FCM/APNs)
final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  return StubPushNotificationService();
});

// Notification preferences state notifier
final notificationPreferencesProvider = StateNotifierProvider<
    NotificationPreferencesNotifier, NotificationPreferencesState>((ref) {
  return NotificationPreferencesNotifier(
    repository: ref.watch(notificationRepositoryProvider),
  );
});
