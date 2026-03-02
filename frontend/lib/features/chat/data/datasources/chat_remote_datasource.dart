import 'package:dio/dio.dart';
import '../models/chat_message_model.dart';

abstract class ChatRemoteDataSource {
  Future<ChatMessageModel> sendMessage(String message);
  Future<List<ChatMessageModel>> getConversationHistory();
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final Dio dio;

  const ChatRemoteDataSourceImpl(this.dio);

  @override
  Future<ChatMessageModel> sendMessage(String message) async {
    final response = await dio.post(
      '/api/chat/message',
      data: {'message': message},
    );
    return ChatMessageModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<ChatMessageModel>> getConversationHistory() async {
    final response = await dio.get('/api/chat/history');
    final data = response.data as List<dynamic>;
    return data
        .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
