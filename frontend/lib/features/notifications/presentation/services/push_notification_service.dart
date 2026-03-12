import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Abstraction for platform push notification token retrieval.
/// Replace StubPushNotificationService with a real implementation
/// (e.g., FirebasePushNotificationService) once native SDKs are configured.
abstract class PushNotificationService {
  /// Get the device token from the platform (APNs/FCM)
  Future<String?> getToken();

  /// Get the current platform identifier
  String getPlatform();
}

/// Stub implementation that returns a placeholder token.
/// Used until firebase_messaging is configured with native platform files.
class StubPushNotificationService implements PushNotificationService {
  @override
  Future<String?> getToken() async {
    // Placeholder — replace with real FCM/APNs token retrieval
    return 'stub-device-token-placeholder';
  }

  @override
  String getPlatform() {
    if (kIsWeb) return 'Web';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    return 'Unknown';
  }
}
