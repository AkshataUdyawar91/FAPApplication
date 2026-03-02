import '../../../../core/utils/either.dart';
import '../../../../core/error/failures.dart';
import '../entities/chat_message.dart';

abstract class ChatRepository {
  Future<Either<Failure, ChatMessage>> sendMessage(String message);
  Future<Either<Failure, List<ChatMessage>>> getConversationHistory();
}
