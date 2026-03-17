import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/datasources/assistant_remote_datasource.dart';
import 'assistant_notifier.dart';

final assistantDataSourceProvider = Provider<AssistantRemoteDataSource>(
  (ref) => AssistantRemoteDataSource(ref.watch(dioProvider)),
);

final assistantNotifierProvider =
    StateNotifierProvider<AssistantNotifier, AssistantState>(
  (ref) => AssistantNotifier(ref.watch(assistantDataSourceProvider)),
);
