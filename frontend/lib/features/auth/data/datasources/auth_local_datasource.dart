import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../models/user_model.dart';

/// Local data source for authentication (secure storage)
abstract class AuthLocalDataSource {
  Future<void> cacheUser(UserModel user);
  Future<UserModel?> getCachedUser();
  Future<void> clearCache();
  Future<void> saveTokens(String accessToken, String refreshToken);
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final FlutterSecureStorage secureStorage;

  static const String _userKey = 'cached_user';
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  AuthLocalDataSourceImpl(this.secureStorage);

  @override
  Future<void> cacheUser(UserModel user) async {
    await secureStorage.write(
      key: _userKey,
      value: json.encode(user.toJson()),
    );
  }

  @override
  Future<UserModel?> getCachedUser() async {
    final userJson = await secureStorage.read(key: _userKey);
    if (userJson != null) {
      return UserModel.fromJson(json.decode(userJson));
    }
    return null;
  }

  @override
  Future<void> clearCache() async {
    await secureStorage.delete(key: _userKey);
    await secureStorage.delete(key: _accessTokenKey);
    await secureStorage.delete(key: _refreshTokenKey);
  }

  @override
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await secureStorage.write(key: _accessTokenKey, value: accessToken);
    await secureStorage.write(key: _refreshTokenKey, value: refreshToken);
  }

  @override
  Future<String?> getAccessToken() async {
    return await secureStorage.read(key: _accessTokenKey);
  }

  @override
  Future<String?> getRefreshToken() async {
    return await secureStorage.read(key: _refreshTokenKey);
  }
}
