import 'package:dio/dio.dart';
import '../models/user_model.dart';

/// Remote data source for authentication
abstract class AuthRemoteDataSource {
  Future<AuthResponse> login(String email, String password);
  Future<void> refreshToken(String refreshToken);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;

  AuthRemoteDataSourceImpl(this.dio);

  @override
  Future<AuthResponse> login(String email, String password) async {
    try {
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
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  @override
  Future<void> refreshToken(String refreshToken) async {
    try {
      final response = await dio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode != 200) {
        throw Exception('Token refresh failed');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }
}

/// Authentication response model
class AuthResponse {
  final UserModel user;
  final String accessToken;
  final String refreshToken;

  AuthResponse({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
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
      accessToken: json['token'] as String,
      refreshToken: '', // Backend doesn't issue refresh tokens yet
    );
  }
}
