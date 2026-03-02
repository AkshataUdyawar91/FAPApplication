import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';

/// Dio client provider
final dioClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Add interceptors
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
  ));

  // Auth interceptor will be added in Task 25
  // Error handling interceptor will be added in Task 25

  return dio;
});
