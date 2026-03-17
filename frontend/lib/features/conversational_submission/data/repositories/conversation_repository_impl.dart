import 'package:dio/dio.dart';
import '../../../../core/utils/either.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/conversation_message.dart';
import '../../domain/entities/po_search_result.dart';
import '../../domain/entities/dealer_result.dart';
import '../../domain/repositories/conversation_repository.dart';
import '../datasources/conversation_remote_datasource.dart';
import '../models/conversation_request_model.dart';

class ConversationRepositoryImpl implements ConversationRepository {
  final ConversationRemoteDataSource remoteDataSource;

  const ConversationRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, ConversationResponseData>> sendMessage({
    String? submissionId,
    required String action,
    String? message,
    String? payloadJson,
  }) async {
    try {
      final request = ConversationRequestModel(
        submissionId: submissionId,
        action: action,
        message: message,
        payloadJson: payloadJson,
      );
      final result = await remoteDataSource.sendMessage(request);
      return Right(ConversationResponseData(
        submissionId: result.submissionId,
        currentStep: result.currentStep,
        botMessage: result.botMessage,
        buttons: result.buttons,
        card: result.card,
        requiresFileUpload: result.requiresFileUpload,
        fileUploadType: result.fileUploadType,
        progressPercent: result.progressPercent,
        error: result.error,
      ),);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getConversationState(
      String submissionId,) async {
    try {
      final result =
          await remoteDataSource.getConversationState(submissionId);
      return Right(result);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ConversationResponseData>> resumeSubmission(
      String submissionId,) async {
    try {
      final result =
          await remoteDataSource.resumeSubmission(submissionId);
      return Right(ConversationResponseData(
        submissionId: result.submissionId,
        currentStep: result.currentStep,
        botMessage: result.botMessage,
        buttons: result.buttons,
        card: result.card,
        requiresFileUpload: result.requiresFileUpload,
        fileUploadType: result.fileUploadType,
        progressPercent: result.progressPercent,
        error: result.error,
      ),);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<POSearchResult>>> searchPurchaseOrders({
    required String vendorCode,
    required String query,
    String status = 'Open,PartiallyConsumed',
  }) async {
    try {
      final result = await remoteDataSource.searchPurchaseOrders(
        vendorCode: vendorCode,
        query: query,
        status: status,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<DealerResult>>> searchDealers({
    required String state,
    required String query,
    int size = 10,
  }) async {
    try {
      final result = await remoteDataSource.searchDealers(
        state: state,
        query: query,
        size: size,
      );
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
          return const AuthFailure('Forbidden');
        } else if (statusCode == 404) {
          return const NotFoundFailure('Resource not found');
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
