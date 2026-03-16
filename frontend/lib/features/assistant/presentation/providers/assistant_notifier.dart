import 'dart:convert';
import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/assistant_remote_datasource.dart';
import '../../data/models/assistant_response_model.dart';

class AssistantMessage extends Equatable {
  final String id;
  final String content;
  final bool isBot;
  final DateTime timestamp;
  final AssistantResponseModel? response;

  const AssistantMessage({
    required this.id,
    required this.content,
    required this.isBot,
    required this.timestamp,
    this.response,
  });

  @override
  List<Object?> get props => [id, content, isBot, timestamp];
}

class AssistantState extends Equatable {
  final List<AssistantMessage> messages;
  final bool isLoading;
  final String? error;
  final POItemModel? selectedPO;
  final String? submissionId;

  const AssistantState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.selectedPO,
    this.submissionId,
  });

  AssistantState copyWith({
    List<AssistantMessage>? messages,
    bool? isLoading,
    String? error,
    POItemModel? selectedPO,
    bool clearSelectedPO = false,
    String? submissionId,
    bool clearSubmissionId = false,
  }) {
    return AssistantState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedPO: clearSelectedPO ? null : (selectedPO ?? this.selectedPO),
      submissionId: clearSubmissionId ? null : (submissionId ?? this.submissionId),
    );
  }

  @override
  List<Object?> get props => [messages, isLoading, error, selectedPO, submissionId];
}

class AssistantNotifier extends StateNotifier<AssistantState> {
  final AssistantRemoteDataSource _dataSource;

  AssistantNotifier(this._dataSource) : super(const AssistantState());

  Future<void> greet() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dataSource.sendMessage(action: 'greet');
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> sendAction(String action, {String? payloadJson}) async {
    _addUserMessage(action.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' '));
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dataSource.sendMessage(action: action, payloadJson: payloadJson);
      _addBotMessage(response);
      if (response.selectedPO != null) {
        state = state.copyWith(selectedPO: response.selectedPO);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> searchPO(String query) async {
    if (query.length < 3) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dataSource.sendMessage(action: 'search_po', message: query);
      _addBotMessage(response, replaceLastBot: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> selectPO(POItemModel po) async {
    _addUserMessage('Selected: ${po.poNumber}');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dataSource.sendMessage(action: 'select_po', payloadJson: jsonEncode({'poId': po.id}));
      _addBotMessage(response);
      if (response.selectedPO != null) {
        state = state.copyWith(selectedPO: response.selectedPO);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> searchState(String query) async {
    if (query.isEmpty) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dataSource.sendMessage(action: 'search_state', message: query);
      _addBotMessage(response, replaceLastBot: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> selectState(String stateName) async {
    _addUserMessage(stateName);
    state = state.copyWith(isLoading: true, error: null);
    try {
      final poId = state.selectedPO?.id;
      final payload = poId != null ? jsonEncode({'poId': poId}) : null;
      final response = await _dataSource.sendMessage(
        action: 'select_state',
        message: stateName,
        payloadJson: payload,
      );
      _addBotMessage(response);
      if (response.submissionId != null) {
        state = state.copyWith(submissionId: response.submissionId);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> listAllStates() async {
    _addUserMessage('Show all states');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dataSource.sendMessage(action: 'list_states');
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> uploadInvoice(Uint8List bytes, String fileName) async {
    _addUserMessage('Uploading invoice: $fileName');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final sid = state.submissionId;
      if (sid == null) {
        state = state.copyWith(isLoading: false, error: 'No active submission. Please start over.');
        return;
      }
      final uploadResult = await _dataSource.uploadInvoice(
        fileBytes: bytes,
        fileName: fileName,
        submissionId: sid,
      );
      final docId = uploadResult['documentId']?.toString() ?? '';
      final response = await _dataSource.sendMessage(
        action: 'invoice_uploaded',
        message: docId,
      );
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> uploadPOFile(Uint8List bytes, String fileName) async {
    _addUserMessage('Uploading: $fileName');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dataSource.uploadPO(fileBytes: bytes, fileName: fileName);
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _addUserMessage(String text) {
    final msg = AssistantMessage(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      content: text,
      isBot: false,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, msg]);
  }

  void _addBotMessage(AssistantResponseModel response, {bool replaceLastBot = false}) {
    final msg = AssistantMessage(
      id: 'bot-${DateTime.now().millisecondsSinceEpoch}',
      content: response.message,
      isBot: true,
      timestamp: DateTime.now(),
      response: response,
    );
    List<AssistantMessage> messages;
    if (replaceLastBot && state.messages.isNotEmpty) {
      final lastBotIdx = state.messages.lastIndexWhere((m) => m.isBot);
      if (lastBotIdx >= 0) {
        messages = [...state.messages];
        messages[lastBotIdx] = msg;
      } else {
        messages = [...state.messages, msg];
      }
    } else {
      messages = [...state.messages, msg];
    }
    state = state.copyWith(messages: messages, isLoading: false);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void reset() {
    state = const AssistantState();
  }
}
