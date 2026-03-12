import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local data source for storing device token ID securely
abstract class NotificationLocalDataSource {
  /// Save the registered device token ID
  Future<void> saveDeviceTokenId(String tokenId);

  /// Get the stored device token ID
  Future<String?> getDeviceTokenId();

  /// Clear the stored device token ID
  Future<void> clearDeviceTokenId();
}

class NotificationLocalDataSourceImpl implements NotificationLocalDataSource {
  final FlutterSecureStorage secureStorage;

  static const String _deviceTokenIdKey = 'device_token_id';

  NotificationLocalDataSourceImpl(this.secureStorage);

  @override
  Future<void> saveDeviceTokenId(String tokenId) async {
    await secureStorage.write(key: _deviceTokenIdKey, value: tokenId);
  }

  @override
  Future<String?> getDeviceTokenId() async {
    return await secureStorage.read(key: _deviceTokenIdKey);
  }

  @override
  Future<void> clearDeviceTokenId() async {
    await secureStorage.delete(key: _deviceTokenIdKey);
  }
}
