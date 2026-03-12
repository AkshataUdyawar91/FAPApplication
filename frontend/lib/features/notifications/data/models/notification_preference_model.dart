import 'package:equatable/equatable.dart';

/// Single notification type preference
class NotificationTypePreference extends Equatable {
  final String notificationType;
  final bool isPushEnabled;
  final bool isEmailEnabled;

  const NotificationTypePreference({
    required this.notificationType,
    required this.isPushEnabled,
    required this.isEmailEnabled,
  });

  factory NotificationTypePreference.fromJson(Map<String, dynamic> json) {
    return NotificationTypePreference(
      notificationType: json['notificationType'] as String,
      isPushEnabled: json['isPushEnabled'] as bool,
      isEmailEnabled: json['isEmailEnabled'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notificationType': notificationType,
      'isPushEnabled': isPushEnabled,
      'isEmailEnabled': isEmailEnabled,
    };
  }

  NotificationTypePreference copyWith({
    bool? isPushEnabled,
    bool? isEmailEnabled,
  }) {
    return NotificationTypePreference(
      notificationType: notificationType,
      isPushEnabled: isPushEnabled ?? this.isPushEnabled,
      isEmailEnabled: isEmailEnabled ?? this.isEmailEnabled,
    );
  }

  @override
  List<Object?> get props => [notificationType, isPushEnabled, isEmailEnabled];
}

/// Notification preferences response from API
class NotificationPreferenceResponse extends Equatable {
  final String userId;
  final List<NotificationTypePreference> preferences;

  const NotificationPreferenceResponse({
    required this.userId,
    required this.preferences,
  });

  factory NotificationPreferenceResponse.fromJson(Map<String, dynamic> json) {
    return NotificationPreferenceResponse(
      userId: json['userId'] as String,
      preferences: (json['preferences'] as List<dynamic>)
          .map((e) => NotificationTypePreference.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [userId, preferences];
}
