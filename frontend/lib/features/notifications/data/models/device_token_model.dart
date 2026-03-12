import 'package:equatable/equatable.dart';

/// Device token response model from API
class DeviceTokenModel extends Equatable {
  final String id;
  final String platform;
  final DateTime registeredAt;
  final DateTime lastUsedAt;
  final bool isActive;

  const DeviceTokenModel({
    required this.id,
    required this.platform,
    required this.registeredAt,
    required this.lastUsedAt,
    required this.isActive,
  });

  factory DeviceTokenModel.fromJson(Map<String, dynamic> json) {
    return DeviceTokenModel(
      id: json['id'] as String,
      platform: json['platform'] as String,
      registeredAt: DateTime.parse(json['registeredAt'] as String),
      lastUsedAt: DateTime.parse(json['lastUsedAt'] as String),
      isActive: json['isActive'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'platform': platform,
      'registeredAt': registeredAt.toIso8601String(),
      'lastUsedAt': lastUsedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  @override
  List<Object?> get props => [id, platform, registeredAt, lastUsedAt, isActive];
}
