import '../../../../core/utils/either.dart';
import '../../../../core/error/failures.dart';
import '../entities/conversation_message.dart';
import '../entities/po_search_result.dart';
import '../entities/dealer_result.dart';

/// Abstract repository for conversational submission operations.
abstract class ConversationRepository {
  /// Sends a conversation action and returns the bot response.
  Future<Either<Failure, ConversationResponseData>> sendMessage({
    String? submissionId,
    required String action,
    String? message,
    String? payloadJson,
  });

  /// Gets the current conversation state for a submission.
  Future<Either<Failure, Map<String, dynamic>>> getConversationState(
      String submissionId,);

  /// Resumes a draft submission from the last completed step.
  Future<Either<Failure, ConversationResponseData>> resumeSubmission(
      String submissionId,);

  /// Searches purchase orders by partial PO number.
  Future<Either<Failure, List<POSearchResult>>> searchPurchaseOrders({
    required String vendorCode,
    required String query,
    String status = 'Open,PartiallyConsumed',
  });

  /// Searches dealers within a state.
  Future<Either<Failure, List<DealerResult>>> searchDealers({
    required String state,
    required String query,
    int size = 10,
  });
}

/// Structured response data from the conversation endpoint.
class ConversationResponseData {
  final String submissionId;
  final int currentStep;
  final String botMessage;
  final List<ActionButton> buttons;
  final CardData? card;
  final bool requiresFileUpload;
  final String? fileUploadType;
  final int progressPercent;
  final String? error;

  const ConversationResponseData({
    required this.submissionId,
    required this.currentStep,
    required this.botMessage,
    this.buttons = const [],
    this.card,
    this.requiresFileUpload = false,
    this.fileUploadType,
    this.progressPercent = 0,
    this.error,
  });
}
