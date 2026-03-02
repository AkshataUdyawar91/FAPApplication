import 'package:dio/dio.dart';
import '../../../../core/utils/either.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_datasource.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource remoteDataSource;

  const ChatRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, ChatMessage>> sendMessage(String message) async {
    try {
      final result = await remoteDataSource.sendMessage(message);
      return Right(result);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ChatMessage>>> getConversationHistory() async {
    try {
      final result = await remoteDataSource.getConversationHistory();
      return Right(result);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Failure _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkFailure('Connection timeout');
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401) {
          return const AuthFailure('Unauthorized');
        } else if (statusCode == 403) {
          return const AuthFailure('Forbidden - HQ role required');
        }
        return ServerFailure(
          error.response?.data?['message'] ?? 'Server error',
        );
      case DioExceptionType.cancel:
        return const ServerFailure('Request cancelled');
      default:
        return const NetworkFailure('Network error');
    }
  }
}
