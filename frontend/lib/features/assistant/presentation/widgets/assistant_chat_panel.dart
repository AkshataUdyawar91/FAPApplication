import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:js_interop';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart' as web;
import '../providers/assistant_notifier.dart';
import '../providers/assistant_providers.dart';
import 'assistant_bubble.dart';
import 'user_bubble.dart';
import 'workflow_action_card.dart';
import 'po_search_list.dart';
import 'file_upload_card.dart';
import 'chat_input_bar.dart';
import '../../data/models/assistant_response_model.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/chat_intent_detector.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../submission/presentation/pages/agency_submission_detail_page.dart';

/// Embeddable side-panel version of the Field Activity Assistant.
/// Mirrors ChatScreen logic but renders as a Column (no Scaffold).
class AssistantChatPanel extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const AssistantChatPanel({super.key, required this.onClose});

  @override
  ConsumerState<AssistantChatPanel> createState() => _AssistantChatPanelState();
}

class _AssistantChatPanelState extends ConsumerState<AssistantChatPanel> {
  final _scrollCtrl = ScrollController();
  bool _initialized = false;
  Timer? _poDebounce;
  final _poSearchCtrl = TextEditingController();
  Timer? _stateDebounce;
  final _stateSearchCtrl = TextEditingController();
  String _inputMode = 'none';
  Timer? _dealerDebounce;
  final _dealerSearchCtrl = TextEditingController();
  final _teamNameCtrl = TextEditingController();
  final _teamCountCtrl = TextEditingController();
  final _photoReplaceCtrl = TextEditingController();
  String _currentTeamPayload = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_initialized) {
        _initialized = true;
        // Restore token from secure storage into authTokenProvider if not already set
        final currentToken = ref.read(authTokenProvider);
        if (currentToken == null || currentToken.isEmpty) {
          final localDataSource = ref.read(authLocalDataSourceProvider);
          final storedToken = await localDataSource.getAccessToken();
          if (storedToken != null && storedToken.isNotEmpty) {
            ref.read(authTokenProvider.notifier).state = storedToken;
          }
        }
        // Always reset to a fresh state every time the panel opens
        ref.read(assistantNotifierProvider.notifier).reset();
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
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
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

  Future<void> _pickInvoiceFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
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
      ref.read(assistantNotifierProvider.notifier).uploadInvoice(file.bytes!, file.name);
    }
  }

  Future<void> _captureInvoiceFromCamera() async {
    final bytes = await _openWebCamera();
    if (bytes == null) return;
    ref.read(assistantNotifierProvider.notifier).uploadInvoice(bytes, 'camera_invoice.jpg');
  }

  Future<void> _captureTeamPhotoFromCamera(String payloadJson) async {
    final bytes = await _openWebCamera();
    if (bytes == null) return;
    ref.read(assistantNotifierProvider.notifier).uploadTeamPhotos([bytes], ['camera_photo.jpg'], payloadJson);
  }

  Future<Uint8List?> _openWebCamera() async {
    if (!kIsWeb) {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera);
      if (photo == null) return null;
      return await photo.readAsBytes();
    }

    // Web: use getUserMedia to access camera, show preview, capture snapshot
    final completer = Completer<Uint8List?>();

    // Create overlay UI
    final overlay = web.HTMLDivElement()
      ..setAttribute('style',
          'position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.85);z-index:99999;display:flex;flex-direction:column;align-items:center;justify-content:center;');

    final video = web.HTMLVideoElement()
      ..setAttribute('autoplay', '')
      ..setAttribute('playsinline', '')
      ..setAttribute('style', 'width:100%;max-width:480px;border-radius:8px;');

    final btnRow = web.HTMLDivElement()
      ..setAttribute('style', 'display:flex;gap:12px;margin-top:16px;');

    final captureBtn = web.HTMLButtonElement()
      ..textContent = 'Capture'
      ..setAttribute('style',
          'padding:12px 32px;background:#003087;color:white;border:none;border-radius:8px;font-size:16px;cursor:pointer;');

    final cancelBtn = web.HTMLButtonElement()
      ..textContent = 'Cancel'
      ..setAttribute('style',
          'padding:12px 32px;background:#666;color:white;border:none;border-radius:8px;font-size:16px;cursor:pointer;');

    btnRow.append(captureBtn);
    btnRow.append(cancelBtn);
    overlay.append(video);
    overlay.append(btnRow);
    web.document.body!.append(overlay);

    web.MediaStream? stream;

    try {
      // Request front camera
      final constraints = {
        'video': {'facingMode': 'user'},
        'audio': false,
      }.jsify();

      stream = await web.window.navigator.mediaDevices
          .getUserMedia(constraints as web.MediaStreamConstraints)
          .toDart;

      video.srcObject = stream;
    } catch (e) {
      overlay.remove();
      if (!completer.isCompleted) completer.complete(null);
      return completer.future;
    }

    void stopStream() {
      final tracks = stream?.getTracks();
      if (tracks != null) {
        for (var i = 0; i < tracks.toDart.length; i++) {
          tracks.toDart[i].stop();
        }
      }
      overlay.remove();
    }

    captureBtn.addEventListener(
      'click',
      (web.Event _) {
        final canvas = web.HTMLCanvasElement()
          ..width = video.videoWidth
          ..height = video.videoHeight;
        final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
        ctx?.drawImage(video, 0, 0);
        // Specify image/jpeg so magic bytes match the .jpg filename
        canvas.toBlob((web.Blob blob) {
          final reader = web.FileReader();
          reader.addEventListener(
            'loadend',
            (web.Event _) {
              stopStream();
              final result = reader.result;
              if (!completer.isCompleted) {
                if (result != null) {
                  final bytes = (result as JSArrayBuffer).toDart.asUint8List();
                  completer.complete(bytes);
                } else {
                  completer.complete(null);
                }
              }
            }.toJS,
          );
          reader.readAsArrayBuffer(blob);
        }.toJS, 'image/jpeg', 0.92.toJS);
      }.toJS,
    );

    cancelBtn.addEventListener(
      'click',
      (web.Event _) {
        stopStream();
        if (!completer.isCompleted) completer.complete(null);
      }.toJS,
    );

    return completer.future;
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

  Future<void> _pickActivitySummaryFile() async {    final result = await FilePicker.platform.pickFiles(
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

  /// Fetch document bytes from backend and show in a fullscreen dialog.
  Future<void> _viewDocument(String docId) async {
    if (docId.isEmpty) return;
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get('/api/documents/$docId/download');
      final data = resp.data as Map<String, dynamic>;
      final base64Content = data['base64Content'] as String? ?? '';
      final contentType = data['contentType'] as String? ?? '';
      final fileName = data['filename'] as String? ?? 'document';
      if (base64Content.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No content available for this document')),
          );
        }
        return;
      }
      final bytes = base64Decode(base64Content);
      final isImage = contentType.startsWith('image/') ||
          fileName.toLowerCase().endsWith('.jpg') ||
          fileName.toLowerCase().endsWith('.jpeg') ||
          fileName.toLowerCase().endsWith('.png');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(children: [
                  Expanded(child: Text(fileName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
              ),
              const Divider(height: 1),
              Flexible(
                child: isImage
                    ? InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain))
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.description, size: 48, color: Color(0xFF6B7280)),
                            const SizedBox(height: 12),
                            Text(fileName, style: const TextStyle(fontSize: 14)),
                            const SizedBox(height: 8),
                            const Text('Preview not available for this file type.', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                          ]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load document: $e')),
        );
      }
    }
  }

  /// Fetch document bytes from backend and trigger browser download.
  Future<void> _downloadDocument(String docId, String fallbackName) async {
    if (docId.isEmpty) return;
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get('/api/documents/$docId/download');
      final data = resp.data as Map<String, dynamic>;
      final base64Content = data['base64Content'] as String? ?? '';
      final contentType = data['contentType'] as String? ?? 'application/octet-stream';
      final fileName = data['filename'] as String? ?? fallbackName;
      if (base64Content.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No content available for download')),
          );
        }
        return;
      }
      if (kIsWeb) {
        final anchor = web.HTMLAnchorElement()
          ..href = 'data:$contentType;base64,$base64Content'
          ..download = fileName
          ..style.display = 'none';
        web.document.body!.append(anchor);
        anchor.click();
        anchor.remove();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded: $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download: $e')),
        );
      }
    }
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
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, -2))],
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _teamNameCtrl,
              decoration: InputDecoration(
                hintText: 'Enter team name...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _submitTeamName(),
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
      );
    }
    if (_inputMode == 'team_count') {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, -2))],
        ),
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
      );
    }
    return ChatInputBar(
      onSend: (text) => _handleTypedInput(text),
      enabled: !state.isLoading,
    );
  }

  void _handleTypedInput(String text) {
    final intent = ChatIntentDetector.detect(text);
    switch (intent) {
      case ChatIntent.greeting:
        ref.read(assistantNotifierProvider.notifier).sendAction('greet', userText: text);
      case ChatIntent.createRequest:
        ref.read(assistantNotifierProvider.notifier).sendAction('create_request', userText: text);
      case ChatIntent.rejectionReason:
        ref.read(assistantNotifierProvider.notifier).sendAction('pending_approvals', userText: text);
      case ChatIntent.statusCheck:
        ref.read(assistantNotifierProvider.notifier).sendAction('message', userText: text);
      case ChatIntent.help:
        ref.read(assistantNotifierProvider.notifier).sendAction('help', userText: text);
      case ChatIntent.fallback:
      case ChatIntent.unknown:
        ref.read(assistantNotifierProvider.notifier).sendAction('message', payloadJson: null, userText: text);
    }
  }

  void _submitTeamName() {
    final name = _teamNameCtrl.text.trim();
    if (name.isEmpty) return;
    _teamNameCtrl.clear();
    ref.read(assistantNotifierProvider.notifier).submitTeamName(name, _currentTeamPayload);
  }

  void _submitTeamCount() {
    final count = _teamCountCtrl.text.trim();
    if (count.isEmpty) return;
    _teamCountCtrl.clear();
    ref.read(assistantNotifierProvider.notifier).submitTeamCount(count, _currentTeamPayload);
  }

  Widget _searchBar(TextEditingController ctrl, String hint, IconData icon, ValueChanged<String> onChanged) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, -2))],
      ),
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
    );
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
          child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF003087))),
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
                      child: Text('Select State', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
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
                              label: Text(c.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF003087))),
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
                      return _stateButton(c.title, () => ref.read(assistantNotifierProvider.notifier).selectState(c.title));
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
                      child: Text('States', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
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
            Text('State confirmed', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500, fontSize: 13)),
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
                child: Text('Upload Invoice', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
              ),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: ref.watch(assistantNotifierProvider).isLoading ? null : _pickInvoiceFile,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text('Upload from device', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF003087))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: ref.watch(assistantNotifierProvider).isLoading ? null : _captureInvoiceFromCamera,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text('Use Camera', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF003087))),
                  ),
                ),
              ]),
              if (ref.watch(assistantNotifierProvider).isLoading && isLast)
                const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Accepted: PDF, JPG, PNG (max 10 MB)', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
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
            Text('Invoice uploaded', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500, fontSize: 13)),
          ]),
        );
      case 'invoice_validation':
        return AssistantBubble(message: msg.content, child: _invoiceValidationCard(r));
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
              _uploadButton('Upload from device', Icons.upload_file, _pickCostSummaryFile),
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
              _uploadButton('Upload from device', Icons.upload_file, _pickActivitySummaryFile),
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
      case 'upload_po':
        return AssistantBubble(
          message: msg.content,
          child: FileUploadCard(
            label: 'Upload Purchase Order',
            allowedFormats: r.allowedFormats ?? ['PDF', 'Word', 'JPG', 'PNG'],
            isUploading: ref.watch(assistantNotifierProvider).isLoading,
            onFileSelected: (bytes, name) => ref.read(assistantNotifierProvider.notifier).uploadPOFile(bytes, name),
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
              ? _dealerList(r.dealers!, r.payloadJson ?? '')
              : null,
        );
      case 'date_picker_start':
        return AssistantBubble(
          message: msg.content,
          child: _datePickerButton('Pick Start & End Date', payloadJson: r.payloadJson ?? ''),
        );
      case 'team_dates_confirm':
        return AssistantBubble(
          message: msg.content,
          child: _teamDatesConfirmButtons(r.payloadJson ?? ''),
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
              Row(children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: ref.watch(assistantNotifierProvider).isLoading
                        ? null
                        : () => _pickMultiplePhotoFiles(r.payloadJson ?? _currentTeamPayload),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003087),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Choose from gallery', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: ref.watch(assistantNotifierProvider).isLoading
                        ? null
                        : () => _captureTeamPhotoFromCamera(r.payloadJson ?? _currentTeamPayload),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF003087),
                      side: const BorderSide(color: Color(0xFF003087)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Use Camera', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ]),
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
              _uploadButton('Upload from device', Icons.upload_file, _pickEnquiryDumpFile),
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
      case 'status_cards':
        return AssistantBubble(
          message: msg.content,
          child: r.statusCards != null && r.statusCards!.isNotEmpty
              ? _statusCardsWidget(r.statusCards!)
              : null,
        );
      case 'pending_claims':
        return AssistantBubble(message: msg.content, child: _pendingClaimsCard(r));
      case 'rejection_history':
        return AssistantBubble(message: msg.content, child: _rejectionHistoryCard(r));
      default:
        return AssistantBubble(message: msg.content);
    }
  }

  Widget _pendingClaimsCard(AssistantResponseModel r) {
    final claims = r.pendingClaims ?? [];
    if (claims.isEmpty) return const SizedBox.shrink();

    // Indian number format helper
    String formatIndian(double amount) {
      if (amount == 0) return '₹0';
      final parts = amount.toStringAsFixed(0).split('');
      final result = StringBuffer();
      final len = parts.length;
      for (int i = 0; i < len; i++) {
        if (i == len - 3 && len > 3) result.write(',');
        else if (i > (len - 3) && (len - i - 1) % 2 == 0 && i < len - 3) result.write(',');
        result.write(parts[i]);
      }
      return '₹${result.toString()}';
    }

    Color statusBg(String color) {
      switch (color) {
        case 'blue':   return const Color(0xFFDBEAFE); // light blue — Pending with CH/RA
        case 'red':    return const Color(0xFFFEE2E2); // light red — Rejected
        case 'green':  return const Color(0xFFDCFCE7); // light green — Approved
        default:       return const Color(0xFFFEF3C7); // amber — Draft / Processing
      }
    }

    Color statusFg(String color) {
      switch (color) {
        case 'blue':   return const Color(0xFF1D4ED8);
        case 'red':    return const Color(0xFFDC2626);
        case 'green':  return const Color(0xFF16A34A);
        default:       return const Color(0xFFD97706); // amber
      }
    }

    final token = ref.read(authTokenProvider) ?? '';
    final userName = ref.read(authNotifierProvider).user?.name ?? '';

    Widget claimCard(PendingClaimItemModel claim) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: FAP ID + Status pill
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      claim.fapId,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusBg(claim.statusColor),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      claim.statusLabel,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusFg(claim.statusColor)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Row 2: PO Number + Invoice Amount
              Row(children: [
                const Icon(Icons.receipt_long, size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 5),
                Text('PO: ${claim.poNumber}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                const SizedBox(width: 16),
                const Text('₹', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                const SizedBox(width: 2),
                Text(
                  claim.invoiceAmount > 0 ? formatIndian(claim.invoiceAmount) : '—',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ]),
              const SizedBox(height: 6),
              // Row 3: State + Date
              Row(children: [
                const Icon(Icons.location_on, size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 5),
                Text(claim.activityState,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                const SizedBox(width: 16),
                const Icon(Icons.calendar_today, size: 13, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 5),
                Text(claim.submittedDate,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              ]),
              const SizedBox(height: 14),
              // View Details button — full stadium shape
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.pushNamed('submission-detail', extra: {
                      'submissionId': claim.submissionId,
                      'token': token,
                      'userName': userName,
                      'poNumber': claim.poNumber == '—' ? '' : claim.poNumber,
                    });
                  },
                  icon: const Icon(Icons.open_in_new, size: 15),
                  label: const Text('View Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF003087),
                    side: const BorderSide(color: Color(0xFF003087), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Scrollable if > 5 claims
    final Widget list = claims.length > 5
        ? SizedBox(
            height: 5 * 160.0,
            child: SingleChildScrollView(
              child: Column(children: claims.map(claimCard).toList()),
            ),
          )
        : Column(children: claims.map(claimCard).toList());

    return list;
  }

  Widget _rejectionHistoryCard(AssistantResponseModel r) {
    final items = r.rejectionItems ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

    final token = ref.read(authTokenProvider) ?? '';
    final userName = ref.read(authNotifierProvider).user?.name ?? '';

    // Indian number format helper (mirrors pending claims)
    String formatIndian(double amount) {
      if (amount == 0) return '₹0';
      final parts = amount.toStringAsFixed(0).split('');
      final result = StringBuffer();
      final len = parts.length;
      for (int i = 0; i < len; i++) {
        if (i == len - 3 && len > 3) result.write(',');
        else if (i > (len - 3) && (len - i - 1) % 2 == 0 && i < len - 3) result.write(',');
        result.write(parts[i]);
      }
      return '₹${result.toString()}';
    }

    Widget card(RejectionItemModel item) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: FAP ID + rejected-by-role pill (light blue)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      item.fapId,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      item.rejectedByRole,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Row 2: receipt icon + PO number + ₹ amount
              Row(children: [
                const Icon(Icons.receipt_long, size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 5),
                Text('PO: ${item.poNumber ?? '—'}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                const SizedBox(width: 16),
                const Text('₹', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                const SizedBox(width: 2),
                const Text('—', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              ]),
              const SizedBox(height: 6),
              // Row 3: location icon + state + calendar icon + date
              Row(children: [
                const Icon(Icons.location_on, size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 5),
                Text(item.activityState ?? '—',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                const SizedBox(width: 16),
                const Icon(Icons.calendar_today, size: 13, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 5),
                Text(item.rejectedAt,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              ]),
              const SizedBox(height: 14),
              // View Details button — full stadium shape, dark blue outlined
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: item.submissionId.isEmpty
                      ? null
                      : () {
                          context.pushNamed('submission-detail', extra: {
                            'submissionId': item.submissionId,
                            'token': token,
                            'userName': userName,
                            'poNumber': item.poNumber == '—' ? '' : (item.poNumber ?? ''),
                          });
                        },
                  icon: const Icon(Icons.open_in_new, size: 15),
                  label: const Text('View Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF003087),
                    side: const BorderSide(color: Color(0xFF003087), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return items.length > 5
        ? SizedBox(
            height: 5 * 160.0,
            child: SingleChildScrollView(child: Column(children: items.map(card).toList())),
          )
        : Column(children: items.map(card).toList());
  }

  Widget _teamProgressIndicator(int current, int total) {    return Row(children: [
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

  Widget _datePickerButton(String label, {required String payloadJson}) {
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
          onPressed: isLoading ? null : () => ref.read(assistantNotifierProvider.notifier).confirmTeam(payloadJson),
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

  Widget _uploadButton(String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: ref.watch(assistantNotifierProvider).isLoading ? null : onTap,
          icon: Icon(icon, size: 18, color: const Color(0xFF003087)),
          label: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF003087))),
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

  Widget _invoiceValidationCard(AssistantResponseModel r) {
    final rules = r.validationRules ?? [];
    final passed = r.passedCount ?? 0;
    final total = rules.length;
    final failed = r.failedCount ?? 0;
    final warned = r.warningCount ?? 0;
    final issues = failed + warned;
    final hasIssues = issues > 0;
    final isLoading = ref.watch(assistantNotifierProvider).isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              // Header
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
                        ],
                      ),
                    ),
                    Text('$passed/$total passed',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
                  ],
                ),
              ),
              // Column headers
              Container(
                color: const Color(0xFFF9FAFB),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Row(children: const [
                  SizedBox(width: 28, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                  Expanded(flex: 4, child: Text('Validation', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                  SizedBox(width: 68, child: Text('Result', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                  Expanded(flex: 3, child: Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Text('Evidence', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                  )),
                ]),
              ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              ...rules.asMap().entries.map((entry) {
                final i = entry.key;
                final rule = entry.value;
                final isPass = rule.passed;
                final resultColor = isPass ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
                final resultBg = isPass ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
                final resultLabel = isPass ? 'PASS' : 'FAIL';
                final foundText = isPass ? (rule.extractedValue ?? '—') : (rule.message ?? rule.extractedValue ?? '—');

                return Container(
                  decoration: BoxDecoration(
                    color: i.isEven ? Colors.white : const Color(0xFFFAFAFA),
                    border: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 28, child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
                    Expanded(flex: 4, child: Text(rule.label, style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
                    SizedBox(
                      width: 68,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: resultBg, borderRadius: BorderRadius.circular(4)),
                        child: Text(resultLabel,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: resultColor)),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Text(foundText,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF111827))),
                      ),
                    ),
                  ]),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // View & Download buttons for invoice
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                final docId = ref.read(assistantNotifierProvider).lastDocumentId ?? '';
                _viewDocument(docId);
              },
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('View'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF003087),
                side: const BorderSide(color: Color(0xFF003087)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                final docId = ref.read(assistantNotifierProvider).lastDocumentId ?? '';
                _downloadDocument(docId, 'invoice');
              },
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Download'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF003087),
                side: const BorderSide(color: Color(0xFF003087)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : () => ref.read(assistantNotifierProvider.notifier).reUploadInvoice(),
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
              onPressed: isLoading ? null : () => ref.read(assistantNotifierProvider.notifier).continueAfterValidation(),
              icon: const Icon(Icons.arrow_forward, size: 14),
              label: Text(hasIssues ? 'Continue with warnings' : 'Continue',
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


  Widget _photoValidationCard(AssistantResponseModel r, bool isLast) {
    final photos = r.photoResults ?? [];
    final isLoading = ref.watch(assistantNotifierProvider).isLoading;
    final payloadJson = r.payloadJson ?? _currentTeamPayload;
    final teamLabel = r.teamContext?.teamName ?? 'Team ${r.teamContext?.currentTeam ?? 1}';
    final teamName = r.teamContext != null ? 'Team ${r.teamContext!.currentTeam}' : 'this team';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.teamContext != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _teamProgressIndicator(r.teamContext!.currentTeam, r.teamContext!.totalTeams),
          ),
        // Team name header
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            teamLabel,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
          ),
        ),
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
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: isLoading
                  ? null
                  : () async {
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
              child: Text('Done $teamName',
                  style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, softWrap: false),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _photoTable(List<PhotoValidationResultModel> photos) {
    bool _rulePassed(PhotoValidationResultModel photo, String keyword) {
      final rule = photo.rules.firstWhere(
        (r) => r.label.toLowerCase().contains(keyword),
        orElse: () => ValidationRuleResultModel(ruleCode: '', type: '', passed: false, isWarning: false, label: ''),
      );
      return rule.passed;
    }

    Widget _badge(bool passed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: passed ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          passed ? 'PASS' : 'FAIL',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: passed ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          ),
        ),
      );
    }

    const headerStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151));

    return Table(
      border: TableBorder.all(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(6)),
      columnWidths: const {
        0: FixedColumnWidth(44),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
        3: FlexColumnWidth(),
        4: FlexColumnWidth(),
        5: FixedColumnWidth(40),
        6: FixedColumnWidth(40),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
          children: [
            _tableCell('Photo', headerStyle),
            _tableCell('Date', headerStyle),
            _tableCell('GPS', headerStyle),
            _tableCell('Blue\nT-shirt', headerStyle),
            _tableCell('3W\nVehicle', headerStyle),
            _tableCell('View', headerStyle),
            _tableCell('Save', headerStyle),
          ],
        ),
        ...photos.map((photo) => TableRow(
          children: [
            _tableCell('${photo.displayOrder}',
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
            _tableBadgeCell(_badge(_rulePassed(photo, 'date'))),
            _tableBadgeCell(_badge(_rulePassed(photo, 'gps'))),
            _tableBadgeCell(_badge(_rulePassed(photo, 'blue'))),
            _tableBadgeCell(_badge(_rulePassed(photo, 'vehicle'))),
            _tableBadgeCell(
              InkWell(
                onTap: photo.photoId.isNotEmpty ? () => _viewDocument(photo.photoId) : null,
                child: Icon(Icons.visibility, size: 18, color: photo.photoId.isNotEmpty ? const Color(0xFF003087) : Colors.grey.shade400),
              ),
            ),
            _tableBadgeCell(
              InkWell(
                onTap: photo.photoId.isNotEmpty ? () => _downloadDocument(photo.photoId, photo.fileName) : null,
                child: Icon(Icons.download, size: 18, color: photo.photoId.isNotEmpty ? const Color(0xFF003087) : Colors.grey.shade400),
              ),
            ),
          ],
        )),
      ],
    );
  }

  Widget _tableBadgeCell(Widget badge) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Center(child: badge),
    );
  }

  Widget _tableCell(String text, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
            style: const TextStyle(fontSize: 12, color: Color(0xFF111827))),
      ]),
    );
  }

  Widget _costSummaryValidationCard(AssistantResponseModel r) {
    final rules = r.validationRules ?? [];
    final passed = r.passedCount ?? 0;
    final total = rules.length;
    final failed = r.failedCount ?? 0;
    final warned = r.warningCount ?? 0;
    final issues = failed + warned;
    final hasIssues = issues > 0;
    final isLoading = ref.watch(assistantNotifierProvider).isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Text('Cost Summary',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                    ),
                    Text('$passed/$total passed',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
                  ],
                ),
              ),
              Container(
                color: const Color(0xFFF9FAFB),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Row(children: const [
                  SizedBox(width: 28, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                  Expanded(flex: 4, child: Text('Validation', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                  SizedBox(width: 68, child: Text('Result', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                  Expanded(flex: 3, child: Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Text('Evidence', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                  )),
                ]),
              ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              ...rules.asMap().entries.map((entry) {
                final i = entry.key;
                final rule = entry.value;
                final isPass = rule.passed;
                final resultColor = isPass ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
                final resultBg = isPass ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
                final resultLabel = isPass ? 'PASS' : 'FAIL';
                final foundText = isPass ? (rule.extractedValue ?? '—') : (rule.message ?? rule.extractedValue ?? '—');
                return Container(
                  decoration: BoxDecoration(
                    color: i.isEven ? Colors.white : const Color(0xFFFAFAFA),
                    border: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 28, child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
                    Expanded(flex: 4, child: Text(rule.label, style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
                    SizedBox(
                      width: 68,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: resultBg, borderRadius: BorderRadius.circular(4)),
                        child: Text(resultLabel,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: resultColor)),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Text(foundText,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF111827))),
                      ),
                    ),
                  ]),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // View & Download buttons for cost summary
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                final docId = ref.read(assistantNotifierProvider).lastDocumentId ?? '';
                _viewDocument(docId);
              },
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('View'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF003087),
                side: const BorderSide(color: Color(0xFF003087)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                final docId = ref.read(assistantNotifierProvider).lastDocumentId ?? '';
                _downloadDocument(docId, 'cost_summary');
              },
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Download'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF003087),
                side: const BorderSide(color: Color(0xFF003087)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : () => ref.read(assistantNotifierProvider.notifier).reUploadCostSummary(),
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
              onPressed: isLoading ? null : () => ref.read(assistantNotifierProvider.notifier).continueAfterCostSummary(),
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
    final total = rules.length;
    final failed = r.failedCount ?? 0;
    final warned = r.warningCount ?? 0;
    final issues = failed + warned;
    final hasIssues = issues > 0;
    final isLoading = ref.watch(assistantNotifierProvider).isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Text('Activity Summary',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                    ),
                    Text('$passed/$total passed',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
                  ],
                ),
              ),
              Container(
                color: const Color(0xFFF9FAFB),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Row(children: const [
                  SizedBox(width: 28, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                  Expanded(flex: 4, child: Text('Validation', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                  SizedBox(width: 68, child: Text('Result', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                  Expanded(flex: 3, child: Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Text('Evidence', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                  )),
                ]),
              ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              ...rules.asMap().entries.map((entry) {
                final i = entry.key;
                final rule = entry.value;
                final isPass = rule.passed;
                final resultColor = isPass ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
                final resultBg = isPass ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
                final resultLabel = isPass ? 'PASS' : 'FAIL';
                final foundText = isPass ? (rule.extractedValue ?? '—') : (rule.message ?? rule.extractedValue ?? '—');
                return Container(
                  decoration: BoxDecoration(
                    color: i.isEven ? Colors.white : const Color(0xFFFAFAFA),
                    border: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 28, child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
                    Expanded(flex: 4, child: Text(rule.label, style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
                    SizedBox(
                      width: 68,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: resultBg, borderRadius: BorderRadius.circular(4)),
                        child: Text(resultLabel,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: resultColor)),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Text(foundText,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF111827))),
                      ),
                    ),
                  ]),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // View & Download buttons for activity summary
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                final docId = ref.read(assistantNotifierProvider).lastDocumentId ?? '';
                _viewDocument(docId);
              },
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('View'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF003087),
                side: const BorderSide(color: Color(0xFF003087)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                final docId = ref.read(assistantNotifierProvider).lastDocumentId ?? '';
                _downloadDocument(docId, 'activity_summary');
              },
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Download'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF003087),
                side: const BorderSide(color: Color(0xFF003087)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : () => ref.read(assistantNotifierProvider.notifier).reUploadActivitySummary(),
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
              onPressed: isLoading ? null : () => ref.read(assistantNotifierProvider.notifier).continueAfterActivity(payloadJson: r.payloadJson),
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

  Widget _enquiryValidationCard(AssistantResponseModel r) {
    final rules = r.validationRules ?? [];
    final passed = r.passedCount ?? 0;
    final total = rules.length;
    final failed = r.failedCount ?? 0;
    final hasIssues = failed > 0;
    final isLoading = ref.watch(assistantNotifierProvider).isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Text('Enquiry Dump',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                    ),
                    Text('$passed/$total passed',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
                  ],
                ),
              ),
              Container(
                color: const Color(0xFFF9FAFB),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Row(children: const [
                  SizedBox(width: 28, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                  Expanded(flex: 4, child: Text('Validation', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                  SizedBox(width: 68, child: Text('Result', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                  Expanded(flex: 3, child: Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Text('Evidence', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                  )),
                ]),
              ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              ...rules.asMap().entries.map((entry) {
                final i = entry.key;
                final rule = entry.value;
                final isPass = rule.passed;
                final resultColor = isPass ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
                final resultBg = isPass ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
                final resultLabel = isPass ? 'PASS' : 'FAIL';
                final foundText = isPass ? (rule.extractedValue ?? '—') : (rule.message ?? rule.extractedValue ?? '—');
                return Container(
                  decoration: BoxDecoration(
                    color: i.isEven ? Colors.white : const Color(0xFFFAFAFA),
                    border: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 28, child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
                    Expanded(flex: 4, child: Text(rule.label, style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
                    SizedBox(
                      width: 68,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: resultBg, borderRadius: BorderRadius.circular(4)),
                        child: Text(resultLabel,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: resultColor)),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Text(foundText,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF111827))),
                      ),
                    ),
                  ]),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // View & Download buttons for enquiry dump
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                final docId = ref.read(assistantNotifierProvider).lastDocumentId ?? '';
                _viewDocument(docId);
              },
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('View'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF003087),
                side: const BorderSide(color: Color(0xFF003087)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                final docId = ref.read(assistantNotifierProvider).lastDocumentId ?? '';
                _downloadDocument(docId, 'enquiry_dump');
              },
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Download'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF003087),
                side: const BorderSide(color: Color(0xFF003087)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
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
              label: Text(hasIssues ? 'Continue with warings' : 'Continue →',
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header — PASS/FAIL badge hidden for PO section
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(children: [
              Expanded(
                child: Text(section.title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
              ),
              if (section.title != 'Purchase Order')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: section.passed ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    section.passed ? 'PASS' : 'FAIL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: section.passed ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                  ),
                ),
            ]),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
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
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF111827))),
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

  /// Maps a nav:// deep-link to the correct detail page.
  /// Agency submissions open in a modal dialog (no sidebar/drawer).
  /// ASM and HQ review pages open in a new browser tab.
  void _openDetailInModal(String deepLink, {String? fapId}) {
    debugPrint('[Chat] View tapped — fapId: $fapId, deepLink: $deepLink');
    final token = ref.read(authTokenProvider) ?? '';
    final userName = ref.read(authNotifierProvider).user?.name ?? '';

    // ASM and HQ pages open in a new tab
    if (deepLink.startsWith('nav://asm-review/') ||
        deepLink.startsWith('nav://hq-review/')) {
      final id = deepLink.startsWith('nav://asm-review/')
          ? deepLink.replaceFirst('nav://asm-review/', '')
          : deepLink.replaceFirst('nav://hq-review/', '');
      final route = deepLink.startsWith('nav://asm-review/')
          ? 'asm-review'
          : 'hq-review';
      web.window.open(
        '${web.window.location.origin}/#/$route/$id',
        '_blank',
      );
      return;
    }

    // Agency detail opens in modal with no sidebar/drawer
    if (deepLink.startsWith('nav://agency-detail/')) {
      final id = deepLink.replaceFirst('nav://agency-detail/', '');
      showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.92,
            height: MediaQuery.of(context).size.height * 0.92,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AgencySubmissionDetailPage(
                key: ValueKey(id),
                submissionId: id,
                token: token,
                userName: userName,
                poNumber: '',
                isModal: true,
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _statusCardsWidget(List<StatusCardModel> cards) {
    Color statusBg(String status) {
      switch (status) {
        case 'Pending with CH':
        case 'Pending with RA':
          return const Color(0xFFDBEAFE); // light blue
        case 'Approved':
          return const Color(0xFFDCFCE7); // light green
        case 'Rejected':
          return const Color(0xFFFEE2E2); // light red
        default:
          return const Color(0xFFFEF3C7); // amber — Draft / Processing / Validating
      }
    }

    Color statusFg(String status) {
      switch (status) {
        case 'Pending with CH':
        case 'Pending with RA':
          return const Color(0xFF1D4ED8);
        case 'Approved':
          return const Color(0xFF16A34A);
        case 'Rejected':
          return const Color(0xFFDC2626);
        default:
          return const Color(0xFFD97706); // amber
      }
    }

    final token = ref.read(authTokenProvider) ?? '';
    final userName = ref.read(authNotifierProvider).user?.name ?? '';

    Widget statusCard(StatusCardModel card) {
      // Extract submissionId from deepLink (e.g. "/submissions/{id}" or just the id)
      final submissionId = card.deepLink.contains('/')
          ? card.deepLink.split('/').last
          : card.deepLink;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: FAP ID + Status pill
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      card.fapId,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusBg(card.status),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      card.status,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusFg(card.status)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Row 2: PO Number + Invoice Number + Amount
              Row(children: [
                const Icon(Icons.receipt_long, size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 5),
                if (card.poNumber != null && card.poNumber!.isNotEmpty) ...[
                  Text('PO: ${card.poNumber!}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                  const SizedBox(width: 10),
                ],
                if (card.invoiceNumber != null && card.invoiceNumber!.isNotEmpty)
                  Text('Inv: ${card.invoiceNumber!}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                if (card.poNumber == null && card.invoiceNumber == null)
                  const Text('—', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                if (card.amount != null && card.amount!.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Text(
                    card.amount!.startsWith('₹') ? card.amount! : '₹${card.amount!}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                ],
              ]),
              const SizedBox(height: 6),
              // Row 3: Date
              Row(children: [
                const Icon(Icons.calendar_today, size: 13, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 5),
                Text(card.submittedDate,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              ]),
              const SizedBox(height: 14),
              // View Details button — full stadium shape
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (submissionId.isNotEmpty) {
                      context.pushNamed('submission-detail', extra: {
                        'submissionId': submissionId,
                        'token': token,
                        'userName': userName,
                        'poNumber': '',
                      });
                    }
                  },
                  icon: const Icon(Icons.open_in_new, size: 15),
                  label: const Text('View Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF003087),
                    side: const BorderSide(color: Color(0xFF003087), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: cards.map(statusCard).toList(),
    );
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
        // STATE SELECTION HIDDEN — auto-selects Maharashtra
        // newMode = 'state';
        newMode = 'none';
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
      if (lastBot.response?.payloadJson != null) {
        setState(() => _currentTeamPayload = lastBot.response!.payloadJson!);
      }
      if (newMode != _inputMode) setState(() => _inputMode = newMode);
    });

    return Container(
      width: 520,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(left: BorderSide(color: Color(0xFFE5E7EB))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(-3, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: const Color(0xFF003087),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 18,
                  child: Icon(Icons.smart_toy, color: Color(0xFF003087), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FieldIQ Assistant',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                      Text('Online', style: TextStyle(fontSize: 12, color: Color(0xFF90CAF9))),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'New conversation',
                  onPressed: () {
                    ref.read(assistantNotifierProvider.notifier).reset();
                    ref.read(assistantNotifierProvider.notifier).greet();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Close',
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          // Error banner
          if (state.error != null)
            MaterialBanner(
              content: Text(state.error!),
              backgroundColor: Colors.red.shade50,
              actions: [
                TextButton(
                  onPressed: () => ref.read(assistantNotifierProvider.notifier).clearError(),
                  child: const Text('DISMISS'),
                ),
              ],
            ),
          // Messages
          Expanded(
            child: state.messages.isEmpty && state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final msg = state.messages[index];
                      if (!msg.isBot) return UserBubble(message: msg.content);
                      final isLastBot = !state.messages.sublist(index + 1).any((m) => m.isBot);
                      return _botMsg(msg, isLast: isLastBot);
                    },
                  ),
          ),
          // Input
          _bottomInput(state),
        ],
      ),
    );
  }
}
