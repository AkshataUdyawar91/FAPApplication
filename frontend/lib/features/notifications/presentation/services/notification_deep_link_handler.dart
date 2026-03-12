import 'package:flutter/material.dart';

/// Handles deep link navigation from notification payloads.
/// Parses the deep link path and navigates using the app's Navigator.
class NotificationDeepLinkHandler {
  final GlobalKey<NavigatorState> navigatorKey;

  NotificationDeepLinkHandler({required this.navigatorKey});

  /// Parse and navigate to the deep link from a notification payload.
  /// Expected payload format: `{ "deepLink": "/submissions/{id}" }`
  /// Falls back to home on invalid or missing deep links.
  void handleNotificationTap(Map<String, dynamic> data) {
    final deepLink = data['deepLink'] as String?;
    if (deepLink == null || deepLink.isEmpty) {
      _navigateToHome();
      return;
    }

    final route = _parseDeepLink(deepLink);
    if (route != null) {
      navigatorKey.currentState?.pushNamed(
        route.name,
        arguments: route.arguments,
      );
    } else {
      _navigateToHome();
    }
  }

  /// Parse a deep link string into a route.
  /// Supported formats:
  ///   - `/submissions/{id}` → submission detail page
  _DeepLinkRoute? _parseDeepLink(String deepLink) {
    final uri = Uri.tryParse(deepLink);
    if (uri == null) return null;

    final segments = uri.pathSegments;

    // /submissions/{id}
    if (segments.length == 2 && segments[0] == 'submissions') {
      return _DeepLinkRoute(
        name: '/agency/submission-detail',
        arguments: {'submissionId': segments[1]},
      );
    }

    return null;
  }

  void _navigateToHome() {
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (_) => false);
  }
}

class _DeepLinkRoute {
  final String name;
  final Map<String, dynamic>? arguments;

  const _DeepLinkRoute({required this.name, this.arguments});
}
