import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/assistant_notifier.dart';
import '../providers/assistant_providers.dart';
import '../widgets/assistant_header.dart';
import '../widgets/assistant_bubble.dart';
import '../widgets/user_bubble.dart';
import '../widgets/workflow_action_card.dart';
import '../widgets/po_search_list.dart';
import '../widgets/file_upload_card.dart';
import '../widgets/chat_input_bar.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/models/assistant_response_model.dart';
import '../../../../core/utils/chat_intent_detector.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollCtrl = ScrollController();
  bool _initialized = false;
  Timer? _poDebounce;
  final _poSearchCtrl = TextEditingController();
  Timer? _stateDebounce;
  final _stateSearchCtrl = TextEditingController();
  Timer? _dealerDebounce;
  final _dealerSearchCtrl = TextEditingController();
  String _inputMode = 'none';
  String _currentTeamPayload = '';
  final _teamNameCtrl = TextEditingController();
  final _photoReplaceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialized) {
        _initialized = true;
        ref.read(assistantNotifierProvider.notifier).greet();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _poDebounce?.cancel();
    _poSearchCtrl.dispose();
    _stateDebounce?.cancel();
    _stateSearchCtrl.dispose();
    _dealerDebounce?.cancel();
    _dealerSearchCtrl.dispose();
    _teamNameCtrl.dispose();
    _teamCountCtrl.dispose();
    _photoReplaceCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onPOSearch(String q) {
    _poDebounce?.cancel();
    if (q.length < 3) return;
    _poDebounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(assistantNotifierProvider.notifier).searchPO(q);
    });
  }

  void _onStateSearch(String q) {
    _stateDebounce?.cancel();
    if (q.isEmpty) return;
    _stateDebounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(assistantNotifierProvider.notifier).searchState(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantNotifierProvider);
    ref.listen<AssistantState>(assistantNotifierProvider, (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length) _scrollToBottom();
      final lastBot = next.messages.lastWhere(
        (m) => m.isBot,
        orElse: () => AssistantMessage(id: '', content: '', isBot: true, timestamp: DateTime(2000)),
      );
      final t = lastBot.response?.type ?? '';
      String newMode;
      if (t == 'po_search' || t == 'po_search_results') {
        newMode = 'po';
      } else if (t == 'state_selection' || t == 'state_search_results') {
        newMode = 'state';
      } else if (t == 'dealer_search' || t == 'dealer_search_results') {
        newMode = 'dealer';
      } else if (t == 'dealer_list') {
        newMode = 'none'; // dropdown — no search bar needed
      } else if (t == 'team_name_input') {
        newMode = 'team_name';
      } else if (t == 'team_count_input') {
        newMode = 'team_count';
      } else {
        newMode = 'none';
      }
      // Carry team payload forward
      if (lastBot.response?.payloadJson != null) {
        setState(() => _currentTeamPayload = lastBot.response!.payloadJson!);
      }
      if (newMode != _inputMode) setState(() => _inputMode = newMode);
    });
    return Scaffold(
      appBar: const AssistantHeader(),
      body: Column(children: [
        if (state.error != null)
          MaterialBanner(
            content: Text(state.error!),
            backgroundColor: Colors.red.shade50,
            actions: [
              TextButton(
                onPressed: () => ref.read(assistantNotifierProvider.notifier).clearError(),
                child: const Text('DISMISS'),
              )
            ],
          ),
        Expanded(
          child: state.messages.isEmpty && state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _msgList(state),
        ),
        _bottomInput(state),
      ]),
    );
  }

  Widget _bottomInput(AssistantState state) {
    if (_inputMode == 'po') {
      return _searchBar(_poSearchCtrl, 'Search PO number (min 3 chars)...', Icons.search, _onPOSearch);
    }
    if (_inputMode == 'state') {
      return _searchBar(_stateSearchCtrl, 'Type state name to search...', Icons.location_on, _onStateSearch);
    }
    if (_inputMode == 'dealer') {
      return _searchBar(_dealerSearchCtrl, 'Type dealer name (min 2 chars)...', Icons.store,
          (q) {
            _dealerDebounce?.cancel();
            if (q.length < 2) return;
            _dealerDebounce = Timer(const Duration(milliseconds: 400), () {
              ref.read(assistantNotifierProvider.notifier).searchDealer(q, _currentTeamPayload);
            });
          });
    }
    if (_inputMode == 'team_name') {
      return _teamNameInput(state);
    }
    if (_inputMode == 'team_count') {
      return _teamCountInput(state);
    }
    return ChatInputBar(
      onSend: (text) => _handleTypedInput(text),
      enabled: !state.isLoading,
    );
  }

  void _handleTypedInput(String text) {
    final intent = ChatIntentDetector.detect(text);
    if (intent == ChatIntent.createRequest) {
      ref.read(assistantNotifierProvider.notifier).sendAction('create_request');
    } else if (intent == ChatIntent.help) {
      ref.read(assistantNotifierProvider.notifier).sendAction('help');
    } else {
      ref.read(assistantNotifierProvider.notifier).sendAction('message', payloadJson: null, userText: text);
    }
  }

  Widget _teamNameInput(AssistantState state) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _teamNameCtrl,
              decoration: InputDecoration(
                hintText: 'Enter team name...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (v) => _submitTeamName(),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: state.isLoading ? null : _submitTeamName,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003087),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            child: const Text('Next', style: TextStyle(color: Colors.white)),
          ),
        ]),
      ),
    );
  }

  void _submitTeamName() {
    final name = _teamNameCtrl.text.trim();
    if (name.isEmpty) return;
    _teamNameCtrl.clear();
    ref.read(assistantNotifierProvider.notifier).submitTeamName(name, _currentTeamPayload);
  }

  final _teamCountCtrl = TextEditingController();

  Widget _teamCountInput(AssistantState state) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _teamCountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter number of teams...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _submitTeamCount(),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: state.isLoading ? null : _submitTeamCount,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003087),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            child: const Text('Next', style: TextStyle(color: Colors.white)),
          ),
        ]),
      ),
    );
  }

  void _submitTeamCount() {
    final count = _teamCountCtrl.text.trim();
    if (count.isEmpty) return;
    _teamCountCtrl.clear();
    ref.read(assistantNotifierProvider.notifier).submitTeamCount(count, _currentTeamPayload);
  }

  Widget _searchBar(
    TextEditingController ctrl,
    String hint,
    IconData icon,
    ValueChanged<String> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        top: false,
        child: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _msgList(AssistantState state) {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      itemCount: state.messages.length,
      itemBuilder: (context, index) {
        final msg = state.messages[index];
        if (!msg.isBot) return UserBubble(message: msg.content);
        // isLastBot: true if no later bot message exists after this index
        final isLastBot = !state.messages.sublist(index + 1).any((m) => m.isBot);
        return _botMsg(msg, isLast: isLastBot);
      },
    );
  }

  Future<void> _pickActivitySummaryFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'xls', 'xlsx'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final file = result.files.single;
      if (file.size > 10 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File size exceeds 10 MB limit')),
          );
        }
        return;
      }
      ref.read(assistantNotifierProvider.notifier).uploadActivitySummary(file.bytes!, file.name);
    }
  }

  Future<void> _pickCostSummaryFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'xls', 'xlsx'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final file = result.files.single;
      if (file.size > 10 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File size exceeds 10 MB limit')),
          );
        }
        return;
      }
      ref.read(assistantNotifierProvider.notifier).uploadCostSummary(file.bytes!, file.name);
    }
  }

  Future<void> _pickEnquiryDumpFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv', 'pdf'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final file = result.files.single;
      if (file.size > 10 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File size exceeds 10 MB limit')),
          );
        }
        return;
      }
      ref.read(assistantNotifierProvider.notifier).uploadEnquiryDump(file.bytes!, file.name);
    }
  }

  Future<void> _pickInvoiceFile() async {    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final file = result.files.single;
      if (file.size > 10 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File size exceeds 10 MB limit')),
        );
        return;
      }
      ref.read(assistantNotifierProvider.notifier).uploadInvoice(file.bytes!, file.name);
    }
  }

  Future<void> _pickMultiplePhotoFiles(String payloadJson) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    if (result.files.length > 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 10 photos per team.')),
        );
      }
      return;
    }
    final photoBytes = <Uint8List>[];
    final fileNames = <String>[];
    for (final file in result.files) {
      if (file.bytes == null) continue;
      photoBytes.add(file.bytes!);
      fileNames.add(file.name);
    }
    if (photoBytes.isEmpty) return;
    ref.read(assistantNotifierProvider.notifier).uploadTeamPhotos(photoBytes, fileNames, payloadJson);
  }

  Future<void> _pickSinglePhotoForReplace(int photoNumber, String payloadJson) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    final sid = ref.read(assistantNotifierProvider).submissionId ?? '';
    // Extract teamNumber from payloadJson so the upload is linked to the right team
    int teamNumber = 1;
    try {
      final ctx = jsonDecode(payloadJson) as Map<String, dynamic>;
      teamNumber = (ctx['currentPhotoTeam'] as num?)?.toInt() ?? 1;
    } catch (_) {}
    final photoIds = await ref.read(assistantNotifierProvider.notifier).uploadSinglePhotoForReplace(
      file.bytes!,
      file.name,
      sid,
      teamNumber,
    );
    if (photoIds.isNotEmpty) {
      ref.read(assistantNotifierProvider.notifier).replacePhoto(photoNumber, photoIds.first, payloadJson);
    }
  }

  Widget _stateButton(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF003087)),
          ),
        ),
      ),
    );
  }

  Widget _botMsg(AssistantMessage msg, {bool isLast = false}) {
    final r = msg.response;
    if (r == null) return AssistantBubble(message: msg.content);
    switch (r.type) {
      case 'greeting':
      case 'help':
        return AssistantBubble(
          message: msg.content,
          child: r.cards != null
              ? Column(
                  children: r.cards!
                      .map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: WorkflowActionCard(
                              card: c,
                              onTap: () => ref.read(assistantNotifierProvider.notifier).sendAction(c.action),
                            ),
                          ))
                      .toList(),
                )
              : null,
        );
      case 'po_search':
      case 'po_search_results':
        return AssistantBubble(
          message: msg.content,
          child: r.poItems != null && r.poItems!.isNotEmpty
              ? POSearchList(
                  items: r.poItems!,
                  onSelect: (po) {
                    _poSearchCtrl.clear();
                    ref.read(assistantNotifierProvider.notifier).selectPO(po);
                  },
                )
              : null,
        );
      case 'state_selection':
        return AssistantBubble(
          message: msg.content,
          child: r.cards != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('Select State',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                    ),
                    ...r.cards!.map((c) {
                      if (c.action == 'list_states') {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => ref.read(assistantNotifierProvider.notifier).listAllStates(),
                              icon: const Icon(Icons.search, size: 18, color: Color(0xFF003087)),
                              label: Text(c.title,
                                  style: const TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF003087))),
                              style: OutlinedButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                          ),
                        );
                      }
                      return _stateButton(
                          c.title, () => ref.read(assistantNotifierProvider.notifier).selectState(c.title));
                    }),
                  ],
                )
              : null,
        );
      case 'state_search_results':
        return AssistantBubble(
          message: msg.content,
          child: r.states != null && r.states!.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('States',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                    ),
                    ...r.states!.map((s) => _stateButton(s, () {
                          _stateSearchCtrl.clear();
                          ref.read(assistantNotifierProvider.notifier).selectState(s);
                        })),
                  ],
                )
              : null,
        );
      case 'state_confirmed':
        return AssistantBubble(
          message: msg.content,
          child: const Row(children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            SizedBox(width: 6),
            Text('State confirmed',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500, fontSize: 13)),
          ]),
        );
      case 'invoice_upload':
        return AssistantBubble(
          message: msg.content,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Upload Invoice',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: ref.watch(assistantNotifierProvider).isLoading ? null : _pickInvoiceFile,
                    icon: const Icon(Icons.upload_file, size: 18, color: Color(0xFF003087)),
                    label: const Text('Upload from device',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF003087))),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),
              if (ref.watch(assistantNotifierProvider).isLoading && isLast)
                const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Accepted: PDF, JPG, PNG (max 10 MB)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ),
            ],
          ),
        );
      case 'invoice_upload_success':
        return AssistantBubble(
          message: msg.content,
          child: const Row(children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            SizedBox(width: 6),
            Text('Invoice uploaded',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500, fontSize: 13)),
          ]),
        );
      case 'activity_summary_upload':
        return AssistantBubble(
          message: msg.content,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Upload Activity Summary',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: ref.watch(assistantNotifierProvider).isLoading ? null : _pickActivitySummaryFile,
                    icon: const Icon(Icons.upload_file, size: 18, color: Color(0xFF003087)),
                    label: const Text('Upload from device',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF003087))),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),
              if (ref.watch(assistantNotifierProvider).isLoading && isLast)
                const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Accepted: PDF, JPG, PNG, XLS, XLSX (max 10 MB)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ),
            ],
          ),
        );
      case 'activity_summary_validation':
        return AssistantBubble(message: msg.content, child: _activitySummaryValidationCard(r));
      case 'cost_summary_upload':
        return AssistantBubble(
          message: msg.content,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Upload Cost Summary',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: ref.watch(assistantNotifierProvider).isLoading ? null : _pickCostSummaryFile,
                    icon: const Icon(Icons.upload_file, size: 18, color: Color(0xFF003087)),
                    label: const Text('Upload from device',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF003087))),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),
              if (ref.watch(assistantNotifierProvider).isLoading && isLast)
                const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Accepted: PDF, JPG, PNG, XLS, XLSX (max 10 MB)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ),
            ],
          ),
        );
      case 'cost_summary_validation':
        return AssistantBubble(message: msg.content, child: _costSummaryValidationCard(r));
      case 'activity_summary_extracted':
        return AssistantBubble(
          message: msg.content,
          child: Row(children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 6),
            const Text('Activity Summary extracted',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500, fontSize: 13)),
          ]),
        );
      case 'invoice_validation':
        return AssistantBubble(message: msg.content, child: _invoiceValidationCard(r));
      case 'upload_po':
        return AssistantBubble(
          message: msg.content,
          child: FileUploadCard(
            label: 'Upload Purchase Order',
            allowedFormats: r.allowedFormats ?? ['PDF', 'Word', 'JPG', 'PNG'],
            isUploading: ref.watch(assistantNotifierProvider).isLoading,
            onFileSelected: (bytes, name) =>
                ref.read(assistantNotifierProvider.notifier).uploadPOFile(bytes, name),
          ),
        );
      case 'upload_success':
        return AssistantBubble(
          message: msg.content,
          child: const Row(children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            SizedBox(width: 6),
            Text('Upload complete', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500, fontSize: 13)),
          ]),
        );
      case 'error':
        return AssistantBubble(
          message: msg.content,
          child: const Row(children: [
            Icon(Icons.error_outline, color: Colors.red, size: 20),
            SizedBox(width: 6),
            Text('Please try again', style: TextStyle(color: Colors.red, fontSize: 13)),
          ]),
        );
      case 'team_name_input':
        return AssistantBubble(
          message: msg.content,
          child: r.teamContext != null
              ? _teamProgressIndicator(r.teamContext!.currentTeam, r.teamContext!.totalTeams)
              : null,
        );
      case 'team_count_input':
        return AssistantBubble(message: msg.content);
      case 'dealer_search':
        return AssistantBubble(
          message: msg.content,
          child: r.teamContext != null
              ? _teamProgressIndicator(r.teamContext!.currentTeam, r.teamContext!.totalTeams)
              : null,
        );
      case 'dealer_list':
      case 'dealer_search_results':
        return AssistantBubble(
          message: msg.content,
          child: r.dealers != null && r.dealers!.isNotEmpty
              ? _dealerList(r.dealers!, r.payloadJson ?? _currentTeamPayload)
              : null,
        );
      case 'date_picker_start':
        return AssistantBubble(
          message: msg.content,
          child: _datePickerButton('Pick Start & End Date', isStart: true, payloadJson: r.payloadJson ?? _currentTeamPayload),
        );
      case 'date_picker_end':
        return AssistantBubble(
          message: msg.content,
          child: _datePickerButton('Pick end date', isStart: false, payloadJson: r.payloadJson ?? _currentTeamPayload),
        );
      case 'team_dates_confirm':
        return AssistantBubble(
          message: msg.content,
          child: _teamDatesConfirmButtons(r.payloadJson ?? _currentTeamPayload),
        );
      case 'team_complete':
        return AssistantBubble(
          message: msg.content,
          child: const Row(children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            SizedBox(width: 6),
            Text('Team saved', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500, fontSize: 13)),
          ]),
        );
      case 'photo_upload':
        return AssistantBubble(
          message: msg.content,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r.teamContext != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _teamProgressIndicator(r.teamContext!.currentTeam, r.teamContext!.totalTeams),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: ref.watch(assistantNotifierProvider).isLoading
                      ? null
                      : () => _pickMultiplePhotoFiles(r.payloadJson ?? _currentTeamPayload),
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text('Choose from gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003087),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              if (ref.watch(assistantNotifierProvider).isLoading && isLast)
                const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Min 3, max 10 photos. Images compressed to ≤500 KB.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ),
            ],
          ),
        );
      case 'photo_validation_results':
        return AssistantBubble(
          message: msg.content,
          child: _photoValidationCard(r, isLast),
        );
      case 'photo_replace_prompt':
        return AssistantBubble(
          message: msg.content,
          child: _photoReplaceInput(r.payloadJson ?? _currentTeamPayload),
        );
      case 'team_summary':
        return AssistantBubble(
          message: msg.content,
          child: _teamSummaryCard(r),
        );
      case 'enquiry_dump_upload':
        return AssistantBubble(
          message: msg.content,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Upload Enquiry Dump',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: ref.watch(assistantNotifierProvider).isLoading ? null : _pickEnquiryDumpFile,
                    icon: const Icon(Icons.upload_file, size: 18, color: Color(0xFF003087)),
                    label: const Text('Upload from device',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF003087))),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),
              if (ref.watch(assistantNotifierProvider).isLoading && isLast)
                const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Accepted: XLSX, CSV, PDF (max 10 MB)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ),
            ],
          ),
        );
      case 'enquiry_dump_validation':
        return AssistantBubble(message: msg.content, child: _enquiryValidationCard(r));
      case 'final_review':
        return AssistantBubble(message: msg.content, child: _finalReviewCard(r, isLast));
      case 'submit_success':
        return AssistantBubble(message: msg.content);
      case 'draft_saved':
        return AssistantBubble(message: msg.content);
      default:
        return AssistantBubble(message: msg.content);
    }
  }


  Widget _teamProgressIndicator(int current, int total) {
    return Row(children: [
      Text('Team $current of $total',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
      const SizedBox(width: 8),
      Expanded(
        child: LinearProgressIndicator(
          value: current / total,
          backgroundColor: Colors.grey.shade200,
          color: const Color(0xFF003087),
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ]);
  }

  Widget _dealerList(List<DealerItemModel> dealers, String payloadJson) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: dealers.map((dealer) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                _dealerSearchCtrl.clear();
                ref.read(assistantNotifierProvider.notifier).selectDealer({
                  'dealerCode': dealer.dealerCode,
                  'dealerName': dealer.dealerName,
                  'city': dealer.city,
                  'state': dealer.state,
                }, payloadJson);
              },
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(dealer.dealerName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF003087))),
                Text('${dealer.city}, ${dealer.state} · ${dealer.dealerCode}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _datePickerButton(String label, {required bool isStart, required String payloadJson}) {
    final isLoading = ref.watch(assistantNotifierProvider).isLoading;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isLoading
            ? null
            : () async {
                final start = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2027),
                  helpText: 'Select start date',
                );
                if (start == null || !mounted) return;

                final end = await showDatePicker(
                  context: context,
                  initialDate: start.add(const Duration(days: 1)),
                  firstDate: start,
                  lastDate: DateTime(2027),
                  helpText: 'Select end date',
                );
                if (end == null || !mounted) return;

                ref.read(assistantNotifierProvider.notifier).submitTeamDates(start, end, payloadJson);
              },
        icon: const Icon(Icons.calendar_today, size: 16),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF003087),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _teamDatesConfirmButtons(String payloadJson) {
    final isLoading = ref.watch(assistantNotifierProvider).isLoading;
    return Row(children: [
      Expanded(
        child: OutlinedButton(
          onPressed: isLoading
              ? null
              : () async {
                  // Re-pick dates — open date pickers locally, then submit
                  final start = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2027),
                    helpText: 'Select start date',
                  );
                  if (start == null || !mounted) return;
                  final end = await showDatePicker(
                    context: context,
                    initialDate: start.add(const Duration(days: 1)),
                    firstDate: start,
                    lastDate: DateTime(2027),
                    helpText: 'Select end date',
                  );
                  if (end == null || !mounted) return;
                  ref.read(assistantNotifierProvider.notifier).submitTeamDates(start, end, payloadJson);
                },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            side: BorderSide(color: Colors.red.shade300),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Re-pick dates'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: ElevatedButton(
          onPressed: isLoading
              ? null
              : () => ref.read(assistantNotifierProvider.notifier).confirmTeam(payloadJson),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF003087),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Confirm ✓'),
        ),
      ),
    ]);
  }

  Widget _invoiceValidationCard(AssistantResponseModel r) {
    final rules = r.validationRules ?? [];
    final passed = r.passedCount ?? 0;
    final total = rules.length;
    final failed = r.failedCount ?? 0;
    final warned = r.warningCount ?? 0;
    final issues = failed + warned;
    final isLoading = ref.watch(assistantNotifierProvider).isLoading;
    final hasIssues = issues > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card container
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Invoice',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                          if (r.fileName != null)
                            Text(r.fileName!,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    Row(children: [
                      Text('$passed/$total passed',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
                      if (issues > 0) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('$issues Issue${issues > 1 ? 's' : ''}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red.shade700)),
                        ),
                      ],
                    ]),
                  ],
                ),
              ),
              // Column headers
              Container(
                color: const Color(0xFFF9FAFB),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Row(children: [
                  const SizedBox(width: 24, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                  const Expanded(flex: 3, child: Text('WHAT WAS CHECKED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                  const SizedBox(width: 56, child: Text('RESULT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                  const Expanded(flex: 3, child: Text('WHAT WAS FOUND', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                ]),
              ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              // Rule rows
              ...rules.asMap().entries.map((entry) {
                final i = entry.key;
                final rule = entry.value;
                final isPass = rule.passed;
                final isWarn = rule.isWarning;
                final resultColor = isPass ? const Color(0xFF16A34A) : (isWarn ? Color(0xFFD97706) : const Color(0xFFDC2626));
                final resultBg = isPass ? const Color(0xFFDCFCE7) : (isWarn ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2));
                final resultLabel = isPass ? 'PASS' : (isWarn ? 'WARN' : 'FAIL');
                final foundText = isPass
                    ? (rule.extractedValue ?? '—')
                    : (rule.message ?? rule.extractedValue ?? '—');
                final foundColor = isPass ? const Color(0xFF111827) : resultColor;

                return Container(
                  decoration: BoxDecoration(
                    color: i.isEven ? Colors.white : const Color(0xFFFAFAFA),
                    border: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                      width: 24,
                      child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(rule.label, style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
                    ),
                    SizedBox(
                      width: 56,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: resultBg, borderRadius: BorderRadius.circular(4)),
                        child: Text(resultLabel,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: resultColor)),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(foundText,
                          style: TextStyle(fontSize: 12, color: foundColor,
                              fontWeight: isPass ? FontWeight.w400 : FontWeight.w500)),
                    ),
                  ]),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Action buttons
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isLoading
                  ? null
                  : () => ref.read(assistantNotifierProvider.notifier).reUploadInvoice(),
              icon: const Icon(Icons.upload_file, size: 16),
              label: const Text('Re-upload invoice'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isLoading
                  ? null
                  : () => ref.read(assistantNotifierProvider.notifier).continueAfterValidation(),
              icon: const Icon(Icons.arrow_forward, size: 14),
              label: Text(hasIssues ? 'Continue with warnings' : 'Continue →',
                  style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, softWrap: false),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003087),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _activitySummaryValidationCard(AssistantResponseModel r) {
    final rules = r.validationRules ?? [];
    final passed = r.passedCount ?? 0;
    final failed = r.failedCount ?? 0;
    final warned = r.warningCount ?? 0;
    final hasIssues = failed > 0 || warned > 0;
    final isLoading = ref.watch(assistantNotifierProvider).isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _validationChip('$passed passed', Colors.green.shade600, Colors.green.shade50),
          if (failed > 0) ...[
            const SizedBox(width: 6),
            _validationChip('$failed failed', Colors.red.shade600, Colors.red.shade50),
          ],
          if (warned > 0) ...[
            const SizedBox(width: 6),
            _validationChip('$warned warning${warned > 1 ? 's' : ''}', Colors.orange.shade700, Colors.orange.shade50),
          ],
        ]),
        const SizedBox(height: 10),
        ...rules.map(_validationRuleRow),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isLoading
                  ? null
                  : () => ref.read(assistantNotifierProvider.notifier).reUploadActivitySummary(),
              icon: const Icon(Icons.upload_file, size: 16),
              label: const Text('Re-upload'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isLoading
                  ? null
                  : () => ref.read(assistantNotifierProvider.notifier).continueAfterActivity(payloadJson: r.payloadJson),
              icon: const Icon(Icons.arrow_forward, size: 14),
              label: Text(hasIssues ? 'Continue with warnings' : 'Continue →',
                  style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, softWrap: false),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003087),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _costSummaryValidationCard(AssistantResponseModel r) {
    final rules = r.validationRules ?? [];
    final passed = r.passedCount ?? 0;
    final failed = r.failedCount ?? 0;
    final warned = r.warningCount ?? 0;
    final hasIssues = failed > 0 || warned > 0;
    final isLoading = ref.watch(assistantNotifierProvider).isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _validationChip('$passed passed', Colors.green.shade600, Colors.green.shade50),
          if (failed > 0) ...[
            const SizedBox(width: 6),
            _validationChip('$failed failed', Colors.red.shade600, Colors.red.shade50),
          ],
          if (warned > 0) ...[
            const SizedBox(width: 6),
            _validationChip('$warned warning${warned > 1 ? 's' : ''}', Colors.orange.shade700, Colors.orange.shade50),
          ],
        ]),
        const SizedBox(height: 10),
        ...rules.map(_validationRuleRow),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isLoading
                  ? null
                  : () => ref.read(assistantNotifierProvider.notifier).reUploadCostSummary(),
              icon: const Icon(Icons.upload_file, size: 16),
              label: const Text('Re-upload'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isLoading
                  ? null
                  : () => ref.read(assistantNotifierProvider.notifier).continueAfterCostSummary(),
              icon: const Icon(Icons.arrow_forward, size: 14),
              label: Text(hasIssues ? 'Continue with warnings' : 'Continue →',
                  style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, softWrap: false),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003087),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _validationChip(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _validationRuleRow(ValidationRuleResultModel rule) {
    final Color iconColor;
    final IconData icon;
    if (rule.passed) {
      icon = Icons.check_circle;
      iconColor = Colors.green.shade600;
    } else if (rule.isWarning) {
      icon = Icons.warning_amber_rounded;
      iconColor = Colors.orange.shade700;
    } else {
      icon = Icons.cancel;
      iconColor = Colors.red.shade600;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rule.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            if (rule.extractedValue != null)
              Text(rule.extractedValue!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            if (rule.message != null && !rule.passed)
              Text(
                rule.message!,
                style: TextStyle(
                  fontSize: 12,
                  color: rule.isWarning ? Colors.orange.shade700 : Colors.red.shade600,
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _photoValidationCard(AssistantResponseModel r, bool isLast) {
    final photos = r.photoResults ?? [];
    final isLoading = ref.watch(assistantNotifierProvider).isLoading;
    final payloadJson = r.payloadJson ?? _currentTeamPayload;
    final teamName = r.teamContext != null ? 'Team ${r.teamContext!.currentTeam}' : 'this team';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.teamContext != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _teamProgressIndicator(r.teamContext!.currentTeam, r.teamContext!.totalTeams),
          ),
        // Photo table
        if (photos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No photo results available.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          )
        else
          _photoTable(photos),
        if (isLoading && isLast)
          const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        const SizedBox(height: 12),
        // Action buttons
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      // Ask which photo number to replace, then open file picker
                      final numCtrl = TextEditingController();
                      final num = await showDialog<int>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Replace Photo'),
                          content: TextField(
                            controller: numCtrl,
                            keyboardType: TextInputType.number,
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: 'Enter photo number (e.g. 1, 2, 3...)',
                            ),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () {
                                final n = int.tryParse(numCtrl.text.trim());
                                if (n != null) Navigator.pop(ctx, n);
                              },
                              child: const Text('Next'),
                            ),
                          ],
                        ),
                      );
                      if (num == null || !mounted) return;
                      _pickSinglePhotoForReplace(num, payloadJson);
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange.shade700,
                side: BorderSide(color: Colors.orange.shade300),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Replace a photo',
                  style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, softWrap: false),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: OutlinedButton(
              onPressed: isLoading
                  ? null
                  : () => ref.read(assistantNotifierProvider.notifier).addMorePhotos(payloadJson),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF003087),
                side: const BorderSide(color: Color(0xFF003087)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Add more photos',
                  style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, softWrap: false),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () => ref.read(assistantNotifierProvider.notifier).doneTeamPhotos(payloadJson),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Done $teamName ✓',
                  style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, softWrap: false),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _photoTable(List<PhotoValidationResultModel> photos) {
    // Map rule label keywords to short column headers
    String _ruleIcon(PhotoValidationResultModel photo, String keyword) {
      final rule = photo.rules.firstWhere(
        (r) => r.label.toLowerCase().contains(keyword),
        orElse: () => ValidationRuleResultModel(ruleCode: '', type: '', passed: false, isWarning: false, label: ''),
      );
      return rule.passed ? '✅' : '❌';
    }

    const headerStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151));
    const cellStyle = TextStyle(fontSize: 13);

    return Table(
      border: TableBorder.all(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(6)),
      columnWidths: const {
        0: FixedColumnWidth(48),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
        3: FlexColumnWidth(),
        4: FlexColumnWidth(),
      },
      children: [
        // Header row
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
          children: [
            _tableCell('Photo', headerStyle),
            _tableCell('Date', headerStyle),
            _tableCell('GPS', headerStyle),
            _tableCell('Blue\nT-shirt', headerStyle),
            _tableCell('3W\nVehicle', headerStyle),
          ],
        ),
        // Data rows
        ...photos.map((photo) => TableRow(
          children: [
            _tableCell('${photo.displayOrder}', cellStyle.copyWith(fontWeight: FontWeight.w600)),
            _tableCell(_ruleIcon(photo, 'date'), cellStyle),
            _tableCell(_ruleIcon(photo, 'gps'), cellStyle),
            _tableCell(_ruleIcon(photo, 'blue') != '✅' ? _ruleIcon(photo, 'tshirt') : _ruleIcon(photo, 'blue'), cellStyle),
            _tableCell(_ruleIcon(photo, '3w') != '✅' ? _ruleIcon(photo, 'vehicle') : _ruleIcon(photo, '3w'), cellStyle),
          ],
        )),
      ],
    );
  }

  Widget _tableCell(String text, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(text, style: style, textAlign: TextAlign.center),
    );
  }

  Widget _photoReplaceInput(String payloadJson) {
    final isLoading = ref.watch(assistantNotifierProvider).isLoading;
    return Row(children: [
      Expanded(
        child: TextField(
          controller: _photoReplaceCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Enter photo number to replace...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
      const SizedBox(width: 8),
      ElevatedButton(
        onPressed: isLoading
            ? null
            : () {
                final num = int.tryParse(_photoReplaceCtrl.text.trim());
                if (num == null) return;
                _photoReplaceCtrl.clear();
                _pickSinglePhotoForReplace(num, payloadJson);
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF003087),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        child: const Text('Replace', style: TextStyle(color: Colors.white)),
      ),
    ]);
  }

  Widget _teamSummaryCard(AssistantResponseModel r) {
    final summaries = r.teamSummaries ?? [];
    final isLoading = ref.watch(assistantNotifierProvider).isLoading;
    final payloadJson = r.payloadJson ?? _currentTeamPayload;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('All Teams Summary',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF003087))),
        ),
        ...summaries.map((team) => _teamSummaryRow(team)),
        if (summaries.isEmpty)
          Text('No team data available.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isLoading
                ? null
                : () => ref.read(assistantNotifierProvider.notifier).continueAfterTeams(payloadJson),
            icon: const Icon(Icons.arrow_forward, size: 14),
            label: const Text('Continue →'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003087),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _teamSummaryRow(TeamSummaryItemModel team) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF003087),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('Team ${team.teamNumber}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(team.teamName,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          ),
        ]),
        const SizedBox(height: 6),
        Text('📍 ${team.dealerName}, ${team.city}, ${team.state}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        Text('📅 ${team.startDate} → ${team.endDate} (${team.workingDays} working days)',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        Text('📸 ${team.photoCount} photos · ${team.photosPassed} passed AI checks',
            style: TextStyle(
              fontSize: 12,
              color: team.photosPassed == team.photoCount ? Colors.green.shade700 : Colors.orange.shade700,
            )),
      ]),
    );
  }

  Widget _enquiryValidationCard(AssistantResponseModel r) {
    final rules = r.validationRules ?? [];
    final passed = r.passedCount ?? 0;
    final failed = r.failedCount ?? 0;
    final isLoading = ref.watch(assistantNotifierProvider).isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _validationChip('$passed passed', Colors.green.shade600, Colors.green.shade50),
          if (failed > 0) ...[
            const SizedBox(width: 6),
            _validationChip('$failed failed', Colors.red.shade600, Colors.red.shade50),
          ],
        ]),
        const SizedBox(height: 10),
        ...rules.map(_validationRuleRow),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isLoading
                  ? null
                  : () => ref.read(assistantNotifierProvider.notifier).reUploadEnquiryDump(),
              icon: const Icon(Icons.upload_file, size: 16),
              label: const Text('Re-upload'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isLoading
                  ? null
                  : () => ref.read(assistantNotifierProvider.notifier).continueAfterEnquiry(),
              icon: const Icon(Icons.arrow_forward, size: 14),
              label: const Text('Continue →', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003087),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _finalReviewCard(AssistantResponseModel r, bool isLast) {
    final sections = r.reviewSections ?? [];
    final isLoading = ref.watch(assistantNotifierProvider).isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...sections.map((section) => _reviewSection(section)),
        if (isLast) ...[
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isLoading
                    ? null
                    : () => ref.read(assistantNotifierProvider.notifier).saveDraftFromChat(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF003087),
                  side: const BorderSide(color: Color(0xFF003087)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Save as Draft'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () => ref.read(assistantNotifierProvider.notifier).submitFromChat(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003087),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Submit'),
              ),
            ),
          ]),
        ],
      ],
    );
  }

  Widget _reviewSection(FinalReviewSectionModel section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: section.passed ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(children: [
              Icon(
                section.passed ? Icons.check_circle : Icons.warning_amber_rounded,
                size: 16,
                color: section.passed ? Colors.green.shade700 : Colors.orange.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                section.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: section.passed ? Colors.green.shade800 : Colors.orange.shade800,
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: section.fields.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(f.label,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    ),
                    Expanded(
                      child: Text(f.value,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
