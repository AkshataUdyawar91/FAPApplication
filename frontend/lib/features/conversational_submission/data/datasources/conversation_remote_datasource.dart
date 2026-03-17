import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/conversation_request_model.dart';
import '../models/conversation_response_model.dart';
import '../models/po_search_result_model.dart';
import '../models/dealer_result_model.dart';

/// Remote datasource for conversational submission API calls.
abstract class ConversationRemoteDataSource {
  /// Sends a conversation action and returns the bot response.
  Future<ConversationResponseModel> sendMessage(
      ConversationRequestModel request,);

  /// Gets the current conversation state for a submission.
  Future<Map<String, dynamic>> getConversationState(String submissionId);

  /// Resumes a draft submission from the last completed step.
  Future<ConversationResponseModel> resumeSubmission(String submissionId);

  /// Searches purchase orders by partial PO number.
  Future<List<POSearchResultModel>> searchPurchaseOrders({
    required String vendorCode,
    required String query,
    String status = 'Open,PartiallyConsumed',
  });

  /// Searches dealers within a state.
  Future<List<DealerResultModel>> searchDealers({
    required String state,
    required String query,
    int size = 10,
  });
}

class ConversationRemoteDataSourceImpl
    implements ConversationRemoteDataSource {
  final Dio dio;

  const ConversationRemoteDataSourceImpl(this.dio);

  @override
  Future<ConversationResponseModel> sendMessage(
      ConversationRequestModel request,) async {
    final response = await dio.post(
      ApiConstants.conversationMessage,
      data: request.toJson(),
    );
    return ConversationResponseModel.fromJson(
        response.data as Map<String, dynamic>,);
  }

  @override
  Future<Map<String, dynamic>> getConversationState(
      String submissionId,) async {
    final response = await dio.get(
      ApiConstants.conversationState(submissionId),
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<ConversationResponseModel> resumeSubmission(
      String submissionId,) async {
    final response = await dio.post(
      ApiConstants.conversationResume(submissionId),
    );
    return ConversationResponseModel.fromJson(
        response.data as Map<String, dynamic>,);
  }

  @override
  Future<List<POSearchResultModel>> searchPurchaseOrders({
    required String vendorCode,
    required String query,
    String status = 'Open,PartiallyConsumed',
  }) async {
    final response = await dio.get(
      ApiConstants.purchaseOrderSearch,
      queryParameters: {
        'vendorCode': vendorCode,
        'q': query,
        'status': status,
      },
    );
    final data = response.data as List<dynamic>;
    return data
        .map((e) =>
            POSearchResultModel.fromJson(e as Map<String, dynamic>),)
        .toList();
  }

  @override
  Future<List<DealerResultModel>> searchDealers({
    required String state,
    required String query,
    int size = 10,
  }) async {
    final response = await dio.get(
      ApiConstants.dealerSearch,
      queryParameters: {
        'state': state,
        'q': query,
        'size': size,
      },
    );
    final data = response.data as List<dynamic>;
    return data
        .map((e) =>
            DealerResultModel.fromJson(e as Map<String, dynamic>),)
        .toList();
  }
}
