import 'dart:async';
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
  String _inputMode = 'none';

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
      } else {
        newMode = 'none';
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
    return ChatInputBar(
      onSend: (text) => ref.read(assistantNotifierProvider.notifier).sendAction('message'),
      enabled: !state.isLoading,
    );
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

  Future<void> _pickInvoiceFile() async {
    final result = await FilePicker.platform.pickFiles(
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
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: ref.watch(assistantNotifierProvider).isLoading ? null : _pickInvoiceFile,
                    icon: const Icon(Icons.camera_alt, size: 18, color: Color(0xFF003087)),
                    label: const Text('Take photo',
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
      default:
        return AssistantBubble(message: msg.content);
    }
  }


  Widget _invoiceValidationCard(AssistantResponseModel r) {
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
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(hasIssues ? 'Continue with warnings' : 'Continue →'),
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
                  : () => ref.read(assistantNotifierProvider.notifier).continueAfterActivity(),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(hasIssues ? 'Continue with warnings' : 'Continue →'),
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
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(hasIssues ? 'Continue with warnings' : 'Continue →'),
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
}
