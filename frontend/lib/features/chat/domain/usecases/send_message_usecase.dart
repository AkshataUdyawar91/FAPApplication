import '../../../../core/utils/either.dart';
import '../../../../core/error/failures.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';

class SendMessageUseCase {
  final ChatRepository repository;

  const SendMessageUseCase(this.repository);

  Future<Either<Failure, ChatMessage>> call(String message) {
    return repository.sendMessage(message);
  }
}
