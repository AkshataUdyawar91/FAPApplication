import 'package:flutter/material.dart';

/// Abstract handler for push notification lifecycle events.
/// Replace [StubPushNotificationHandler] with a real implementation
/// once firebase_messaging is configured with native platform files.
abstract class PushNotificationHandler {
  /// Initialize notification listeners and request permissions
  Future<void> initialize();

  /// Get the current device token from the platform
  Future<String?> getToken();

  /// Handle an incoming notification while the app is in the foreground
  void onMessageReceived(Map<String, dynamic> data);

  /// Handle a notification tap (user tapped the notification)
  void onNotificationTapped(Map<String, dynamic> data);
}

/// Callback type for notification tap navigation
typedef NotificationTapCallback = void Function(Map<String, dynamic> data);

/// Stub implementation for push notification handling.
/// Shows a SnackBar for foreground notifications.
/// Can be replaced with real FCM/APNs handler later.
class StubPushNotificationHandler implements PushNotificationHandler {
  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;
  final NotificationTapCallback? onTap;

  StubPushNotificationHandler({
    this.scaffoldMessengerKey,
    this.onTap,
  });

  @override
  Future<void> initialize() async {
    // Stub — real implementation would request permissions and set up
    // FCM/APNs message listeners here
  }

  @override
  Future<String?> getToken() async {
    // Stub — real implementation would call FirebaseMessaging.instance.getToken()
    return 'stub-device-token-placeholder';
  }

  @override
  void onMessageReceived(Map<String, dynamic> data) {
    final title = data['title'] as String? ?? 'Notification';
    final body = data['body'] as String? ?? '';

    // Show foreground notification as a SnackBar
    scaffoldMessengerKey?.currentState?.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (body.isNotEmpty) Text(body),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => onNotificationTapped(data),
        ),
      ),
    );
  }

  @override
  void onNotificationTapped(Map<String, dynamic> data) {
    onTap?.call(data);
  }
}
