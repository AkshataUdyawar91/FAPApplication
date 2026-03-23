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
  final String? lastDocumentId;
  final String? teamPayloadJson; // carries team context across steps

  const AssistantState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.selectedPO,
    this.submissionId,
    this.lastDocumentId,
    this.teamPayloadJson,
  });

  AssistantState copyWith({
    List<AssistantMessage>? messages,
    bool? isLoading,
    String? error,
    POItemModel? selectedPO,
    bool clearSelectedPO = false,
    String? submissionId,
    bool clearSubmissionId = false,
    String? lastDocumentId,
    String? teamPayloadJson,
  }) {
    return AssistantState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedPO: clearSelectedPO ? null : (selectedPO ?? this.selectedPO),
      submissionId: clearSubmissionId ? null : (submissionId ?? this.submissionId),
      lastDocumentId: lastDocumentId ?? this.lastDocumentId,
      teamPayloadJson: teamPayloadJson ?? this.teamPayloadJson,
    );
  }

  @override
  List<Object?> get props => [messages, isLoading, error, selectedPO, submissionId, lastDocumentId, teamPayloadJson];
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
    const _actionLabels = <String, String>{
      'view_requests': '',
      'pending_approvals': '',
      'create_request': 'Start a new submission',
    };
    final label = _actionLabels[action];
    if (label != null && label.isNotEmpty) _addUserMessage(label);
    else if (label == null) _addUserMessage(action
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' '));
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
      final response = await _dataSource.sendMessage(
        action: 'select_po',
        payloadJson: jsonEncode({'poId': po.id}),
      );
      _addBotMessage(response);
      if (response.selectedPO != null) {
        state = state.copyWith(selectedPO: response.selectedPO);
      }
      if (response.submissionId != null) {
        state = state.copyWith(submissionId: response.submissionId);
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
      state = state.copyWith(lastDocumentId: docId);

      // Poll until AI extraction completes (max 120s, every 3s)
      const maxAttempts = 40;
      for (var i = 0; i < maxAttempts; i++) {
        final status = await _dataSource.getDocumentExtractionStatus(docId);
        if (status == 'extracted') break;
        await Future.delayed(const Duration(seconds: 3));
      }

      final response = await _dataSource.sendMessage(
        action: 'invoice_uploaded',
        message: docId,
      );
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> uploadActivitySummary(Uint8List bytes, String fileName) async {
    _addUserMessage('Uploading activity summary: $fileName');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final sid = state.submissionId;
      if (sid == null) {
        state = state.copyWith(isLoading: false, error: 'No active submission. Please start over.');
        return;
      }
      final uploadResult = await _dataSource.uploadActivitySummary(
        fileBytes: bytes,
        fileName: fileName,
        submissionId: sid,
      );
      final docId = uploadResult['documentId']?.toString() ?? '';
      state = state.copyWith(lastDocumentId: docId);

      // Poll until extraction completes (max 120s, every 3s)
      const maxAttempts = 40;
      for (var i = 0; i < maxAttempts; i++) {
        final status = await _dataSource.getDocumentExtractionStatus(docId);
        if (status == 'extracted') break;
        await Future.delayed(const Duration(seconds: 3));
      }

      final response = await _dataSource.sendMessage(
        action: 'activity_summary_uploaded',
        message: docId,
      );
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> continueAfterActivity({String? payloadJson}) async {
    _addUserMessage('Continue');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final sid = state.submissionId;
      // Prefer the payloadJson passed from the activity summary card (contains costSummaryDocumentId)
      // so the backend can read the exact cost summary document instead of falling back to stale data
      String? payload = payloadJson;
      if (payload == null && sid != null) {
        payload = jsonEncode({'submissionId': sid});
      }
      final response = await _dataSource.sendMessage(
        action: 'continue_after_activity',
        payloadJson: payload,
      );
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> reUploadActivitySummary() async {
    _addUserMessage('Re-upload activity summary');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dataSource.sendMessage(action: 'reupload_activity_summary');
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> continueAfterValidation() async {
    _addUserMessage('Continue with warnings');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final docId = state.lastDocumentId;
      final response = await _dataSource.sendMessage(
        action: 'continue_invoice',
        payloadJson: docId != null ? jsonEncode({'documentId': docId}) : null,
      );
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> reUploadInvoice() async {
    _addUserMessage('Re-upload invoice');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dataSource.sendMessage(action: 'reupload_invoice');
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> uploadCostSummary(Uint8List bytes, String fileName) async {
    _addUserMessage('Uploading cost summary: $fileName');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final sid = state.submissionId;
      if (sid == null) {
        state = state.copyWith(isLoading: false, error: 'No active submission. Please start over.');
        return;
      }
      final uploadResult = await _dataSource.uploadCostSummary(
        fileBytes: bytes,
        fileName: fileName,
        submissionId: sid,
      );
      final docId = uploadResult['documentId']?.toString() ?? '';
      state = state.copyWith(lastDocumentId: docId);

      const maxAttempts = 40;
      for (var i = 0; i < maxAttempts; i++) {
        final status = await _dataSource.getDocumentExtractionStatus(docId);
        if (status == 'extracted') break;
        await Future.delayed(const Duration(seconds: 3));
      }

      final response = await _dataSource.sendMessage(
        action: 'cost_summary_uploaded',
        message: docId,
      );
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> continueAfterCostSummary() async {
    _addUserMessage('Continue');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dataSource.sendMessage(action: 'continue_after_cost_summary');
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> reUploadCostSummary() async {
    _addUserMessage('Re-upload cost summary');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dataSource.sendMessage(action: 'reupload_cost_summary');
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

  // ── Phase 8: Team Details ──────────────────────────────────────────────

  Future<void> submitTeamCount(String count, String payloadJson) async {
    _addUserMessage(count);
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dataSource.sendMessage(
        action: 'submit_team_count',
        message: count,
        payloadJson: payloadJson,
      );
      if (response.payloadJson != null) {
        state = state.copyWith(teamPayloadJson: response.payloadJson);
      }
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> submitTeamName(String teamName, String payloadJson) async {
    _addUserMessage(teamName);
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dataSource.sendMessage(
        action: 'submit_team_name',
        message: teamName,
        payloadJson: payloadJson,
      );
      if (response.payloadJson != null) {
        state = state.copyWith(teamPayloadJson: response.payloadJson);
      }
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> searchDealer(String query, String payloadJson) async {
    if (query.length < 2) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dataSource.sendMessage(
        action: 'search_dealer',
        message: query,
        payloadJson: payloadJson,
      );
      _addBotMessage(response, replaceLastBot: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> selectDealer(Map<String, dynamic> dealer, String payloadJson) async {
    _addUserMessage('${dealer['dealerName']}, ${dealer['city']}');
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Merge dealer into payload
      final ctx = jsonDecode(payloadJson) as Map<String, dynamic>;
      ctx['selectedDealer'] = dealer;
      final newPayload = jsonEncode(ctx);
      final response = await _dataSource.sendMessage(
        action: 'select_dealer',
        payloadJson: newPayload,
      );
      if (response.payloadJson != null) {
        state = state.copyWith(teamPayloadJson: response.payloadJson);
      }
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> submitTeamDates(DateTime startDate, DateTime endDate, String payloadJson) async {
    _addUserMessage('${_fmt(startDate)} → ${_fmt(endDate)}');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final ctx = jsonDecode(payloadJson) as Map<String, dynamic>;
      ctx['startDate'] = startDate.toIso8601String();
      ctx['endDate'] = endDate.toIso8601String();
      final newPayload = jsonEncode(ctx);
      final response = await _dataSource.sendMessage(
        action: 'submit_team_dates',
        payloadJson: newPayload,
      );
      if (response.payloadJson != null) {
        state = state.copyWith(teamPayloadJson: response.payloadJson);
      }
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> confirmTeam(String payloadJson) async {
    _addUserMessage('Confirm');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dataSource.sendMessage(
        action: 'confirm_team',
        payloadJson: payloadJson,
      );
      if (response.payloadJson != null) {
        state = state.copyWith(teamPayloadJson: response.payloadJson);
      }
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}-${_months[d.month - 1]}-${d.year}';
  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  // ── Phase 9: Photo Proofs Upload ──────────────────────────────────────

  Future<void> uploadTeamPhotos(List<Uint8List> photoBytes, List<String> fileNames, String payloadJson) async {
    _addUserMessage('Uploading ${photoBytes.length} photo(s)...');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final ctx = jsonDecode(payloadJson) as Map<String, dynamic>;
      final sid = state.submissionId ?? ctx['submissionId']?.toString() ?? '';
      final teamNumber = (ctx['currentPhotoTeam'] as num?)?.toInt() ?? 1;

      final photoIds = await _dataSource.uploadTeamPhotos(
        photoBytes: photoBytes,
        fileNames: fileNames,
        submissionId: sid,
        teamNumber: teamNumber,
      );

      // Poll until EXIF/AI extraction completes for all photos (max 120s, every 3s)
      const maxAttempts = 40;
      for (final photoId in photoIds) {
        for (var i = 0; i < maxAttempts; i++) {
          final status = await _dataSource.getDocumentExtractionStatus(photoId);
          if (status == 'extracted') break;
          await Future.delayed(const Duration(seconds: 3));
        }
      }

      final response = await _dataSource.sendMessage(
        action: 'photos_uploaded',
        message: photoIds.join(','),
        payloadJson: payloadJson,
      );
      if (response.payloadJson != null) {
        state = state.copyWith(teamPayloadJson: response.payloadJson);
      }
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> doneTeamPhotos(String payloadJson) async {
    _addUserMessage('Done ✓');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dataSource.sendMessage(action: 'done_team_photos', payloadJson: payloadJson);
      if (response.payloadJson != null) {
        state = state.copyWith(teamPayloadJson: response.payloadJson);
      }
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addMorePhotos(String payloadJson) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dataSource.sendMessage(action: 'add_more_photos', payloadJson: payloadJson);
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> replacePhoto(int photoNumber, String newPhotoId, String payloadJson) async {
    _addUserMessage('Replace photo $photoNumber');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dataSource.sendMessage(
        action: 'replace_photo',
        message: '$photoNumber,$newPhotoId',
        payloadJson: payloadJson,
      );
      if (response.payloadJson != null) {
        state = state.copyWith(teamPayloadJson: response.payloadJson);
      }
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Phase 10: Enquiry Dump Upload ─────────────────────────────────────

  Future<void> continueAfterTeams(String payloadJson) async {
    _addUserMessage('Continue');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dataSource.sendMessage(
        action: 'continue_after_teams',
        payloadJson: payloadJson,
      );
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> uploadEnquiryDump(Uint8List bytes, String fileName) async {
    _addUserMessage('Uploading enquiry dump: $fileName');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final sid = state.submissionId;
      if (sid == null) {
        state = state.copyWith(isLoading: false, error: 'No active submission. Please start over.');
        return;
      }
      final uploadResult = await _dataSource.uploadEnquiryDump(
        fileBytes: bytes,
        fileName: fileName,
        submissionId: sid,
      );
      final docId = uploadResult['documentId']?.toString() ?? '';
      state = state.copyWith(lastDocumentId: docId);

      const maxAttempts = 40;
      for (var i = 0; i < maxAttempts; i++) {
        final status = await _dataSource.getDocumentExtractionStatus(docId);
        if (status == 'extracted') break;
        await Future.delayed(const Duration(seconds: 3));
      }

      final response = await _dataSource.sendMessage(
        action: 'enquiry_dump_uploaded',
        message: docId,
      );
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> reUploadEnquiryDump() async {
    _addUserMessage('Re-upload enquiry dump');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dataSource.sendMessage(action: 'reupload_enquiry_dump');
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> continueAfterEnquiry() async {
    _addUserMessage('Continue');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final submissionId = state.submissionId;
      final payloadJson = submissionId != null
          ? '{"submissionId":"$submissionId"}'
          : null;
      final response = await _dataSource.sendMessage(
        action: 'continue_after_enquiry',
        payloadJson: payloadJson,
      );
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> submitFromChat() async {
    _addUserMessage('Submit');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final submissionId = state.submissionId;
      final payloadJson = submissionId != null
          ? '{"submissionId":"$submissionId"}'
          : null;
      final response = await _dataSource.sendMessage(
        action: 'submit_from_chat',
        payloadJson: payloadJson,
      );
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> saveDraftFromChat() async {
    _addUserMessage('Save as Draft');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final sid = state.submissionId;
      final payload = sid != null ? '{"submissionId":"$sid"}' : null;
      final response = await _dataSource.sendMessage(
        action: 'save_draft_from_chat',
        payloadJson: payload,
      );
      _addBotMessage(response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Uploads a single photo for replacement and returns the photo ID list.
  Future<List<String>> uploadSinglePhotoForReplace(    Uint8List photoBytes,
    String fileName,
    String submissionId,
    int teamNumber,
  ) async {
    try {
      return await _dataSource.uploadTeamPhotos(
        photoBytes: [photoBytes],
        fileNames: [fileName],
        submissionId: submissionId,
        teamNumber: teamNumber,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return [];
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
