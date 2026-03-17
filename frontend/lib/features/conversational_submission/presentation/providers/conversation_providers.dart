import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/datasources/conversation_remote_datasource.dart';
import '../../data/datasources/signalr_datasource.dart';
import '../../data/repositories/conversation_repository_impl.dart';
import '../../domain/repositories/conversation_repository.dart';
import 'conversation_notifier.dart';
import 'file_upload_notifier.dart';
import 'signalr_notifier.dart';

// --- Data layer providers ---

final conversationRemoteDataSourceProvider =
    Provider<ConversationRemoteDataSource>(
  (ref) => ConversationRemoteDataSourceImpl(ref.watch(dioClientProvider)),
);

final signalRDataSourceProvider = Provider<SignalRDataSource>(
  (ref) => SignalRDataSourceImpl(),
);

// --- Repository provider ---

final conversationRepositoryProvider = Provider<ConversationRepository>(
  (ref) => ConversationRepositoryImpl(
    ref.watch(conversationRemoteDataSourceProvider),
  ),
);

// --- Presentation layer providers ---

final conversationNotifierProvider =
    StateNotifierProvider<ConversationNotifier, ConversationChatState>(
  (ref) => ConversationNotifier(
    ref.watch(conversationRepositoryProvider),
  ),
);

final signalRNotifierProvider =
    StateNotifierProvider<SignalRNotifier, SignalRState>(
  (ref) => SignalRNotifier(
    ref.watch(signalRDataSourceProvider),
    ref.watch(conversationNotifierProvider.notifier),
  ),
);

// --- File upload provider ---

final fileUploadNotifierProvider =
    StateNotifierProvider<FileUploadNotifier, FileUploadState>(
  (ref) => FileUploadNotifier(ref.watch(dioClientProvider)),
);
