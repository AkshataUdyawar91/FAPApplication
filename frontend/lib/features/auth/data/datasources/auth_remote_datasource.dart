import 'package:dio/dio.dart';
import '../models/user_model.dart';

/// Remote data source for authentication
abstract class AuthRemoteDataSource {
  Future<AuthResponse> login(String email, String password);
  Future<void> refreshToken(String token);
  Future<String> getSsoAuthorizeUrl(String redirectUri);
  Future<AuthResponse> ssoLogin(String code, String redirectUri);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;

  AuthRemoteDataSourceImpl(this.dio);

  @override
  Future<AuthResponse> login(String email, String password) async {
    final response = await dio.post(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      return AuthResponse.fromJson(response.data);
    } else {
      throw Exception('Login failed');
    }
  }

  @override
  Future<void> refreshToken(String token) async {
    final response = await dio.post(
      '/auth/refresh',
      data: {'token': token},
    );

    if (response.statusCode != 200) {
      throw Exception('Token refresh failed');
    }
  }

  @override
  Future<String> getSsoAuthorizeUrl(String redirectUri) async {
    final response = await dio.get(
      '/auth/sso/authorize',
      queryParameters: {'redirectUri': redirectUri},
    );

    if (response.statusCode == 200) {
      return response.data['authorizeUrl'] as String;
    } else {
      throw Exception('Failed to get SSO authorize URL');
    }
  }

  @override
  Future<AuthResponse> ssoLogin(String code, String redirectUri) async {
    final response = await dio.post(
      '/auth/sso/token',
      data: {
        'code': code,
        'redirectUri': redirectUri,
      },
    );

    if (response.statusCode == 200) {
      return AuthResponse.fromJson(response.data);
    } else {
      throw Exception('SSO login failed');
    }
  }
}

/// Authentication response matching backend LoginResponse DTO.
/// Backend returns: { token, userId, email, role, expiresAt }
class AuthResponse {
  final UserModel user;
  final String token;

  AuthResponse({
    required this.user,
    required this.token,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // Backend returns flat: { token, userId, email, fullName, role, expiresAt }
    final user = UserModel(
      id: json['userId'] as String,
      email: json['email'] as String,
      name: json['fullName'] as String,
      role: json['role'] as String,
    );

    return AuthResponse(
      user: user,
      token: json['token'] as String,
    );
  }
}
