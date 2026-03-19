import 'package:dio/dio.dart';
import '../models/user_model.dart';

/// Remote data source for authentication
abstract class AuthRemoteDataSource {
  Future<AuthResponse> login(String email, String password);
  Future<void> refreshToken(String token);
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
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Login failed: $message');
    }
  }

  @override
  Future<void> refreshToken(String token) async {
    try {
      final response = await dio.post(
        '/auth/refresh',
        data: {'token': token},
      );

      if (response.statusCode != 200) {
        throw Exception('Token refresh failed');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
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
    return AuthResponse(
      user: UserModel(
        id: json['userId'].toString(),
        email: json['email'] as String,
        name: json['email'] as String, // Backend doesn't return fullName, use email
        role: json['role'] as String,
      ),
      token: json['token'] as String,
    );
  }
}
