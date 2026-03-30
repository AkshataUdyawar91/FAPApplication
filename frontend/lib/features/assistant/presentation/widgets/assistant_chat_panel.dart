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
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/failures.dart';

/// Embeddable side-panel version of the Field Activity Assistant.
/// Mirrors ChatScreen logic but renders as a Column (no Scaffold).
class AssistantChatPanel extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onNewRequest;
  final VoidCallback? onSubmissionComplete;
  final bool isFullWidth;

  const AssistantChatPanel({
    super.key,
    required this.onClose,
    this.onNewRequest,
    this.onSubmissionComplete,
    this.isFullWidth = false,
  });

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
    // Determine how many photos already exist for this team
    int existingPhotos = 0;
    try {
      final ctx = jsonDecode(payloadJson) as Map<String, dynamic>;
      existingPhotos = (ctx['totalPhotos'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    // Min 3 only applies on the first upload (no existing photos yet)
    if (existingPhotos == 0 && result.files.length < 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please upload at least 3 photos. Minimum 3 photos required.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }
    if (result.files.length > 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 10 photos per upload. Please select up to 10 photos.')),
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
      final resp = await dio.get('/documents/$docId/download');
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
        ErrorHandler.show(context, failure: ServerFailure(e.toString()));
      }
    }
  }

  /// Fetch document bytes from backend and trigger browser download.
  Future<void> _downloadDocument(String docId, String fallbackName) async {
    if (docId.isEmpty) return;
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get('/documents/$docId/download');
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
        ErrorHandler.show(context, failure: ServerFailure(e.toString()));
      }
    }
  }

  Widget _buildStepTracker(int currentStep) {
    const steps = [
      (label: 'Invoice', icon: Icons.receipt_long),
      (label: 'Cost Summary', icon: Icons.attach_money),
      (label: 'Activity Summary', icon: Icons.bar_chart),
      (label: 'Team & Photos', icon: Icons.group),
      (label: 'Enquiry Dump', icon: Icons.inbox),
    ];
    return Container(
      color: const Color(0xFFF8FAFF),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress fraction
          Row(
            children: [
              const Text('Progress', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              const Spacer(),
              Text(
                currentStep > 0 ? '${currentStep.clamp(0, steps.length)} / ${steps.length}' : '0 / ${steps.length}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF003087)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: currentStep > 0 ? (currentStep / steps.length).clamp(0.0, 1.0) : 0,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF003087)),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 12),
          // Step chips — use LayoutBuilder so they fill width and center properly
          LayoutBuilder(
            builder: (context, constraints) {
              const chipGap = 8.0;
              final chipWidth = (constraints.maxWidth - chipGap * (steps.length - 1)) / steps.length;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(steps.length, (i) {
                  final stepNum = i + 1;
                  final isDone = currentStep > stepNum;
                  final isActive = currentStep == stepNum;
                  return Padding(
                    padding: EdgeInsets.only(right: i < steps.length - 1 ? chipGap : 0),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: chipWidth,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDone
                                  ? const Color(0xFF10B981)
                                  : isActive
                                      ? const Color(0xFF003087)
                                      : const Color(0xFFD1D5DB),
                              width: isDone || isActive ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                steps[i].icon,
                                size: 20,
                                color: isDone
                                    ? const Color(0xFF059669)
                                    : isActive
                                        ? const Color(0xFF003087)
                                        : const Color(0xFF9CA3AF),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                steps[i].label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                  color: isDone
                                      ? const Color(0xFF059669)
                                      : isActive
                                          ? const Color(0xFF003087)
                                          : const Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Green tick badge at top-right when step is done
                        if (isDone)
                          Positioned(
                            top: -5,
                            right: -5,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 11,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF003087))),
        ),
      ),
    );
  }

  Widget _botMsg(AssistantMessage msg, {bool isLast = false}) {
    final r = msg.response;
    if (r == null) return AssistantBubble(message: msg.content, isActive: isLast);
    switch (r.type) {
      case 'greeting':
      case 'help':
        return AssistantBubble(
          message: msg.content,
          isActive: isLast,
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
      case 'po_list':
        return AssistantBubble(
          message: msg.content,
          isActive: isLast,
          child: r.poItems != null && r.poItems!.isNotEmpty
              ? Container(
                  constraints: const BoxConstraints(maxHeight: 320),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: r.poItems!.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE5E7EB)),
                      itemBuilder: (context, i) {
                        final po = r.poItems![i];
                        return InkWell(
                          onTap: isLast
                              ? () => ref.read(assistantNotifierProvider.notifier).selectPO(po)
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    po.poNumber,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF003087),
                                    ),
                                  ),
                                ),
                                if (isLast)
                                  const Icon(Icons.chevron_right, size: 18, color: Color(0xFF9CA3AF)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                )
              : null,
        );
      case 'po_search':
      case 'po_search_results':
        return AssistantBubble(
          message: msg.content,
          isActive: isLast,
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
          isActive: isLast,
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
          isActive: isLast,
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
          isActive: isLast,
          child: const Row(children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            SizedBox(width: 6),
            Text('State confirmed', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500, fontSize: 13)),
          ]),
        );
      case 'invoice_upload':
        return AssistantBubble(
          message: msg.content,
          isActive: isLast,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Upload Invoice', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                ElevatedButton(
                  onPressed: ref.watch(assistantNotifierProvider).isLoading ? null : _pickInvoiceFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003087),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Upload from device', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: ref.watch(assistantNotifierProvider).isLoading ? null : _captureInvoiceFromCamera,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003087),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Use Camera', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
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
          isActive: isLast,
          child: const Row(children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            SizedBox(width: 6),
            Text('Invoice uploaded', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500, fontSize: 13)),
          ]),
        );
      case 'invoice_validation':
        return AssistantBubble(message: msg.content, isActive: isLast, greyChild: false, child: _invoiceValidationCard(r, isLast));
      case 'cost_summary_upload':
        return AssistantBubble(
          message: msg.content,
          isActive: isLast,
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
        return AssistantBubble(message: msg.content, isActive: isLast, greyChild: false, child: _costSummaryValidationCard(r, isLast));
      case 'activity_summary_upload':
        return AssistantBubble(
          message: msg.content,
          isActive: isLast,
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
        return AssistantBubble(message: msg.content, isActive: isLast, greyChild: false, child: _activitySummaryValidationCard(r, isLast));
      case 'upload_po':
        return AssistantBubble(
          message: msg.content,
          isActive: isLast,
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
          isActive: isLast,
          child: const Row(children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            SizedBox(width: 6),
            Text('Upload complete', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500, fontSize: 13)),
          ]),
        );
      case 'error':
        return AssistantBubble(
          message: msg.content,
          isActive: isLast,
          child: const Row(children: [
            Icon(Icons.error_outline, color: Colors.red, size: 20),
            SizedBox(width: 6),
            Text('Please try again', style: TextStyle(color: Colors.red, fontSize: 13)),
          ]),
        );
      case 'team_name_input':
        return AssistantBubble(
          message: msg.content,
          isActive: isLast,
        );
      case 'team_count_input':
        return AssistantBubble(message: msg.content, isActive: isLast);
      case 'dealer_search':
        return AssistantBubble(
          message: msg.content,
          isActive: isLast,
        );
      case 'dealer_list':
      case 'dealer_search_results':
        return AssistantBubble(
          message: msg.content,
          isActive: isLast,
          child: r.dealers != null && r.dealers!.isNotEmpty
              ? _dealerList(r.dealers!, r.payloadJson ?? '')
              : null,
        );
      case 'date_picker_start':
        return AssistantBubble(
          message: msg.content,
          isActive: isLast,
          child: _datePickerButton('Pick Start & End Date', payloadJson: r.payloadJson ?? ''),
        );
      case 'team_dates_confirm':
        return AssistantBubble(
          message: msg.content,
          isActive: isLast,
          child: _teamDatesConfirmButtons(r.payloadJson ?? ''),
        );
      case 'photo_upload':
        return AssistantBubble(
          message: msg.content,
          isActive: isLast,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                ElevatedButton(
                  onPressed: ref.watch(assistantNotifierProvider).isLoading
                      ? null
                      : () => _pickMultiplePhotoFiles(r.payloadJson ?? _currentTeamPayload),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003087),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Choose from gallery', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: ref.watch(assistantNotifierProvider).isLoading
                      ? null
                      : () => _captureTeamPhotoFromCamera(r.payloadJson ?? _currentTeamPayload),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003087),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Use Camera', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ]),
              if (ref.watch(assistantNotifierProvider).isLoading && isLast)
                const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Min 3 photos, max 10. Images compressed to ≤500 KB.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ),
            ],
          ),
        );
      case 'photo_validation_results':
        return AssistantBubble(
          message: msg.content.split('\n').first,
          isActive: isLast,
          child: _photoValidationCard(r, isLast),
        );
      case 'photo_replace_prompt':
        return AssistantBubble(
          message: msg.content,
          isActive: isLast,
          child: _photoReplaceInput(r.payloadJson ?? _currentTeamPayload),
        );
      case 'team_summary':
        return AssistantBubble(
          message: msg.content,
          isActive: isLast,
          child: _teamSummaryCard(r),
        );
      case 'enquiry_dump_upload':
        return AssistantBubble(
          message: msg.content,
          isActive: isLast,
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
        return AssistantBubble(
          message: msg.content,
          isActive: isLast,
          child: isLast
              ? Center(
                  child: ElevatedButton.icon(
                    onPressed: ref.watch(assistantNotifierProvider).isLoading
                        ? null
                        : () => ref.read(assistantNotifierProvider.notifier).continueAfterEnquiry(),
                    icon: const Icon(Icons.arrow_forward, size: 14),
                    label: const Text('Continue →', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003087),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                )
              : null,
        );
      case 'final_review':
        return AssistantBubble(message: msg.content, isActive: isLast, child: _finalReviewCard(r, isLast));
      case 'submit_success':
        if (isLast) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onSubmissionComplete?.call();
          });
        }
        return AssistantBubble(message: msg.content, isActive: isLast);
      case 'draft_saved':
        return AssistantBubble(message: msg.content, isActive: isLast);
      case 'status_cards':
        return AssistantBubble(
          message: msg.content,
          child: r.statusCards != null && r.statusCards!.isNotEmpty
              ? _statusCardsWidget(r.statusCards!)
              : null,
        );
      case 'pending_claims':
        return AssistantBubble(message: msg.content, isActive: isLast, child: _pendingClaimsCard(r));
      case 'rejection_history':
        return AssistantBubble(message: msg.content, isActive: isLast, child: _rejectionHistoryCard(r));
      default:
        return AssistantBubble(message: msg.content, isActive: isLast);
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(dealer.dealerName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF003087))),
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
    return Center(
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
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF003087),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _teamDatesConfirmButtons(String payloadJson) {
    final isLoading = ref.watch(assistantNotifierProvider).isLoading;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      ElevatedButton(
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
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Re-pick dates', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      const SizedBox(width: 8),
      ElevatedButton(
        onPressed: isLoading ? null : () => ref.read(assistantNotifierProvider.notifier).confirmTeam(payloadJson),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF003087),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Confirm ✓', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    ]);
  }

  Widget _uploadButton(String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Center(
        child: ElevatedButton.icon(
          onPressed: ref.watch(assistantNotifierProvider).isLoading ? null : onTap,
          icon: Icon(icon, size: 18, color: Colors.white),
          label: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF003087),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }

  Widget _invoiceValidationCard(AssistantResponseModel r, bool isLast) {
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(children: const [
                  Expanded(flex: 1, child: Text('#', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87))),
                  Expanded(flex: 4, child: Text('Validation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87))),
                  Expanded(flex: 2, child: Text('Result', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87))),
                  Expanded(flex: 3, child: Text('Evidence', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87))),
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
                    Expanded(flex: 1, child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
                    Expanded(flex: 4, child: Text(rule.label, style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: resultBg, borderRadius: BorderRadius.circular(4)),
                          child: Text(resultLabel,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: resultColor)),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(foundText,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF111827))),
                    ),
                  ]),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IgnorePointer(
          ignoring: !isLast,
          child: Opacity(
            opacity: isLast ? 1.0 : 0.4,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : () => ref.read(assistantNotifierProvider.notifier).reUploadInvoice(),
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Re-upload invoice', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : () => ref.read(assistantNotifierProvider.notifier).continueAfterValidation(),
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: Text(hasIssues ? 'Continue with warnings' : 'Continue',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, softWrap: false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003087),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }


  Widget _photoValidationCard(AssistantResponseModel r, bool isLast) {
    // final photos = r.photoResults ?? []; // hidden — table not shown
    final isLoading = ref.watch(assistantNotifierProvider).isLoading;
    final payloadJson = r.payloadJson ?? _currentTeamPayload;
    // final teamLabel = r.teamContext?.teamName ?? 'Team ${r.teamContext?.currentTeam ?? 1}'; // hidden
    final teamName = r.teamContext != null ? 'Team ${r.teamContext!.currentTeam}' : 'this team';

    // Parse totalPhotos from payloadJson to decide if "Upload More" should show
    int totalPhotos = 0;
    try {
      final ctx = jsonDecode(payloadJson) as Map<String, dynamic>;
      totalPhotos = (ctx['totalPhotos'] as num?)?.toInt() ?? 0;
    } catch (_) {}
    final canUploadMore = totalPhotos < 50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isLoading && isLast)
          const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (canUploadMore) ...[
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () => ref.read(assistantNotifierProvider.notifier).addMorePhotos(payloadJson),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003087),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Upload more photos',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, softWrap: false),
            ),
            const SizedBox(width: 8),
          ],
          ElevatedButton(
            onPressed: isLoading
                ? null
                : () => ref.read(assistantNotifierProvider.notifier).doneTeamPhotos(payloadJson),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Done $teamName',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, softWrap: false),
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
        5: FixedColumnWidth(56),
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
              photo.photoId.isNotEmpty
                  ? InkWell(
                      onTap: () => _showPhotoPopup(photo.photoId, photo.fileName),
                      child: const Text(
                        'View',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF003087),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    )
                  : const Text('—', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            ),
          ],
        )),
      ],
    );
  }

  /// Fetch photo bytes and show in a fullscreen popup with X to close.
  Future<void> _showPhotoPopup(String photoId, String fileName) async {
    if (photoId.isEmpty) return;
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get('/hierarchical/photos/$photoId/download');
      final data = resp.data as Map<String, dynamic>;
      final base64Content = data['base64Content'] as String? ?? '';
      if (base64Content.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo not available')),
          );
        }
        return;
      }
      final bytes = base64Decode(base64Content);
      if (!mounted) return;
      showDialog(
        context: context,
        barrierColor: Colors.black87,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  constrained: true,
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: -12,
                right: -12,
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 18, color: Color(0xFF111827)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ErrorHandler.show(context, failure: ServerFailure(e.toString()));
      }
    }
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
        if (summaries.isNotEmpty) _buildAggregatedPhotoSummaryTable(summaries),
        if (summaries.isNotEmpty) _buildFailedPhotosGrid(summaries),
        const SizedBox(height: 12),
        ...summaries.map((team) => _teamSummaryRow(team)),
        if (summaries.isEmpty)
          Text('No team data available.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(height: 12),
        Center(
          child: ElevatedButton.icon(
            onPressed: isLoading
                ? null
                : () => ref.read(assistantNotifierProvider.notifier).continueAfterTeams(payloadJson),
            icon: const Icon(Icons.arrow_forward, size: 14),
            label: const Text('Continue →', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003087),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAggregatedPhotoSummaryTable(List<TeamSummaryItemModel> summaries) {
    final totalPhotos = summaries.fold(0, (sum, t) => sum + t.photoCount);
    final totalUniquePhotoDays = summaries.fold(0, (sum, t) => sum + t.uniquePhotoDays);
    final totalActivityDays = summaries.isNotEmpty ? summaries.first.activitySummaryDays : 0;
    final totalWithDate = summaries.fold(0, (sum, t) => sum + t.photosWithDate);
    final totalWithGps = summaries.fold(0, (sum, t) => sum + t.photosWithGps);
    final totalWithBlueTshirt = summaries.fold(0, (sum, t) => sum + t.photosWithBlueTshirt);
    final totalWithVehicle = summaries.fold(0, (sum, t) => sum + t.photosWithVehicle);

    final daysMatch = totalUniquePhotoDays == totalActivityDays;

    // (sno, label, passed, evidence)
    final rows = [
      ('1', 'Photo Count',               true,                                    '$totalPhotos photos uploaded'),
      ('2', 'Date on Photos',            totalWithDate == totalPhotos,            '$totalWithDate/$totalPhotos photos have date mentioned'),
      ('3', 'GPS Coordinates',           totalWithGps == totalPhotos,             '$totalWithGps/$totalPhotos photos have coordinates present'),
      ('4', 'No. of Days',               daysMatch,                               'Unique photo days: $totalUniquePhotoDays | Activity Summary days: $totalActivityDays'),
      ('5', 'Promoter wearing Blue T-shirt', totalWithBlueTshirt == totalPhotos,  '$totalWithBlueTshirt/$totalPhotos photos have promoters wear blue T-shirt'),
      ('6', 'Branded 3 Wheeler',         totalWithVehicle == totalPhotos,         '$totalWithVehicle/$totalPhotos photos have Branded 3 Wheeler'),
    ];

    Widget passBadge(bool passed) => Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: passed ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          passed ? 'PASS' : 'FAIL',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: passed ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          ),
        ),
      ),
    );

    return Container(
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
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(children: const [
              Expanded(flex: 1, child: Text('S.No',       style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87))),
              Expanded(flex: 4, child: Text('Validation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87))),
              Expanded(flex: 2, child: Text('Result',     style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87))),
              Expanded(flex: 4, child: Text('Evidence',   style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87))),
            ]),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          ...rows.asMap().entries.map((entry) {
            final i = entry.key;
            final (sno, label, passed, evidence) = entry.value;
            return Container(
              decoration: BoxDecoration(
                color: i.isEven ? Colors.white : const Color(0xFFFAFAFA),
                border: i < rows.length - 1
                    ? const Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5))
                    : null,
                borderRadius: i == rows.length - 1
                    ? const BorderRadius.only(bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10))
                    : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(flex: 1, child: Text(sno,      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
                Expanded(flex: 4, child: Text(label,    style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
                Expanded(flex: 2, child: passBadge(passed)),
                Expanded(flex: 4, child: Text(evidence, style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFailedPhotosGrid(List<TeamSummaryItemModel> summaries) {
    final allFailedIds = summaries
        .expand((t) => t.failedPhotoIds)
        .toList();

    if (allFailedIds.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Failed Photos',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allFailedIds.map((photoId) => _failedPhotoThumb(photoId)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _failedPhotoThumb(String photoId) {
    return GestureDetector(
      onTap: () => _showPhotoPopup(photoId, ''),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDC2626), width: 2),
          color: Colors.grey.shade100,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: _PhotoThumbLoader(photoId: photoId, dio: ref.read(dioProvider)),
        ),
      ),
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

  Widget _costSummaryValidationCard(AssistantResponseModel r, bool isLast) {
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(children: const [
                  Expanded(flex: 1, child: Text('#', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87))),
                  Expanded(flex: 4, child: Text('Validation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87))),
                  Expanded(flex: 2, child: Text('Result', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87))),
                  Expanded(flex: 3, child: Text('Evidence', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87))),
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
                    Expanded(flex: 1, child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
                    Expanded(flex: 4, child: Text(rule.label, style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: resultBg, borderRadius: BorderRadius.circular(4)),
                          child: Text(resultLabel,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: resultColor)),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(foundText,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF111827))),
                    ),
                  ]),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IgnorePointer(
          ignoring: !isLast,
          child: Opacity(
            opacity: isLast ? 1.0 : 0.4,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ElevatedButton.icon(
                onPressed: isLoading ? null : () => ref.read(assistantNotifierProvider.notifier).reUploadCostSummary(),
                icon: const Icon(Icons.upload_file, size: 16),
                label: const Text('Re-upload', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: isLoading ? null : () => ref.read(assistantNotifierProvider.notifier).continueAfterCostSummary(),
                icon: const Icon(Icons.arrow_forward, size: 14),
                label: Text(hasIssues ? 'Continue with warnings' : 'Continue →',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, softWrap: false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003087),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _activitySummaryValidationCard(AssistantResponseModel r, bool isLast) {
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(children: const [
                  Expanded(flex: 1, child: Text('#', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87))),
                  Expanded(flex: 4, child: Text('Validation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87))),
                  Expanded(flex: 2, child: Text('Result', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87))),
                  Expanded(flex: 3, child: Text('Evidence', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87))),
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
                    Expanded(flex: 1, child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
                    Expanded(flex: 4, child: Text(rule.label, style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: resultBg, borderRadius: BorderRadius.circular(4)),
                          child: Text(resultLabel,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: resultColor)),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(foundText,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF111827))),
                    ),
                  ]),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IgnorePointer(
          ignoring: !isLast,
          child: Opacity(
            opacity: isLast ? 1.0 : 0.4,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ElevatedButton.icon(
                onPressed: isLoading ? null : () => ref.read(assistantNotifierProvider.notifier).reUploadActivitySummary(),
                icon: const Icon(Icons.upload_file, size: 16),
                label: const Text('Re-upload', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: isLoading ? null : () => ref.read(assistantNotifierProvider.notifier).continueAfterActivity(payloadJson: r.payloadJson),
                icon: const Icon(Icons.arrow_forward, size: 14),
                label: Text(hasIssues ? 'Continue with warnings' : 'Continue →',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, softWrap: false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003087),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ]),
          ),
        ),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(children: const [
                  Expanded(flex: 1, child: Text('#', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87))),
                  Expanded(flex: 4, child: Text('Validation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87))),
                  Expanded(flex: 2, child: Text('Result', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87))),
                  Expanded(flex: 3, child: Text('Evidence', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87))),
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
                    Expanded(flex: 1, child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
                    Expanded(flex: 4, child: Text(rule.label, style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: resultBg, borderRadius: BorderRadius.circular(4)),
                          child: Text(resultLabel,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: resultColor)),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(foundText,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF111827))),
                    ),
                  ]),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton.icon(
            onPressed: isLoading
                ? null
                : () => ref.read(assistantNotifierProvider.notifier).reUploadEnquiryDump(),
            icon: const Icon(Icons.upload_file, size: 16),
            label: const Text('Re-upload', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: isLoading
                ? null
                : () => ref.read(assistantNotifierProvider.notifier).continueAfterEnquiry(),
            icon: const Icon(Icons.arrow_forward, size: 14),
            label: Text(hasIssues ? 'Continue with warnings' : 'Continue →',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, softWrap: false),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003087),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton(
            onPressed: isLoading
                ? null
                : () => ref.read(assistantNotifierProvider.notifier).saveDraftFromChat(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003087),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save as Draft', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: isLoading
                ? null
                  : () => ref.read(assistantNotifierProvider.notifier).submitFromChat(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
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
          return const Color(0xFFDBEAFE);
        case 'Approved':
          return const Color(0xFFDCFCE7);
        case 'Rejected by CH':
        case 'Rejected by RA':
          return const Color(0xFFFEE2E2);
        default:
          return const Color(0xFFFEF3C7);
      }
    }

    Color statusFg(String status) {
      switch (status) {
        case 'Pending with CH':
        case 'Pending with RA':
          return const Color(0xFF1D4ED8);
        case 'Approved':
          return const Color(0xFF16A34A);
        case 'Rejected by CH':
        case 'Rejected by RA':
          return const Color(0xFFDC2626);
        default:
          return const Color(0xFFD97706);
      }
    }

    String statusLabel(String status) {
      switch (status) {
        case 'Rejected by CH': return 'Returned by Circle Head';
        case 'Rejected by RA': return 'Returned by RA';
        default: return status;
      }
    }

    final token = ref.read(authTokenProvider) ?? '';
    final userName = ref.read(authNotifierProvider).user?.name ?? '';

    Widget statusCard(StatusCardModel card) {
      final submissionId = card.deepLink.contains('/')
          ? card.deepLink.split('/').last
          : card.deepLink;
      final isRejected = card.status == 'Rejected by CH' || card.status == 'Rejected by RA';

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
                      statusLabel(card.status),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusFg(card.status)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Row 2: reviewer name + date (for rejected) OR PO/Invoice/Amount (for pending)
              if (isRejected) ...[
                Row(children: [
                  const Icon(Icons.person_outline, size: 14, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 5),
                  Text(
                    card.reviewerName?.isNotEmpty == true ? card.reviewerName! : '—',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(width: 14),
                  const Icon(Icons.calendar_today, size: 13, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 5),
                  Text(card.submittedDate, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                ]),
                const SizedBox(height: 10),
                // Reason box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1EE),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFCCBC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Reason',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFB91C1C))),
                      const SizedBox(height: 6),
                      Text(
                        card.rejectionReason?.isNotEmpty == true ? card.rejectionReason! : 'No reason provided.',
                        style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C)),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Row(children: [
                  const Icon(Icons.receipt_long, size: 14, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 5),
                  if (card.poNumber != null && card.poNumber!.isNotEmpty) ...[
                    Text('PO: ${card.poNumber!}', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                    const SizedBox(width: 10),
                  ],
                  if (card.invoiceNumber != null && card.invoiceNumber!.isNotEmpty)
                    Text('Inv: ${card.invoiceNumber!}', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                  if (card.amount != null && card.amount!.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Text(
                      card.amount!.startsWith('₹') ? card.amount! : '₹${card.amount!}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                  ],
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.calendar_today, size: 13, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 5),
                  Text(card.submittedDate, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                ]),
              ],
              const SizedBox(height: 4),
              if (!isRejected) ...[
                const SizedBox(height: 10),
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
      } else if (t == 'po_list') {
        newMode = 'none'; // scrollable list — no search bar needed
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
      if (lastBot.response?.payloadJson != null) {
        setState(() => _currentTeamPayload = lastBot.response!.payloadJson!);
      }
      if (newMode != _inputMode) setState(() => _inputMode = newMode);

      // Show error toast for assistant errors
      if (next.error != null && (prev == null || prev.error == null)) {
        ErrorHandler.show(context, failure: ErrorHandler.failureFromMessage(next.error!));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(assistantNotifierProvider.notifier).clearError();
          }
        });
      }
    });

    return Container(
      width: widget.isFullWidth ? double.infinity : 520,
      decoration: BoxDecoration(
        color: Colors.white,
        border: widget.isFullWidth
            ? null
            : const Border(left: BorderSide(color: Color(0xFFE5E7EB))),
        boxShadow: widget.isFullWidth
            ? null
            : [
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
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFF003087), width: 2)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF003087),
                  radius: 18,
                  child: Icon(Icons.smart_toy, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FieldIQ Assistant',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF003087))),
                      Text('Online', style: TextStyle(fontSize: 12, color: Color(0xFF003087))),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF003087)),
                  tooltip: 'New conversation',
                  onPressed: () {
                    ref.read(assistantNotifierProvider.notifier).reset();
                    ref.read(assistantNotifierProvider.notifier).greet();
                  },
                ),
              ],
            ),
          ),
          // Step tracker — only visible during submission flow
          if (state.isSubmissionFlow) _buildStepTracker(state.currentStep),
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
                      if (!msg.isBot) {
                        // User bubble is active only if no bot message follows it
                        final hasLaterBot = state.messages.sublist(index + 1).any((m) => m.isBot);
                        return UserBubble(
                          key: ValueKey('${msg.id}_$hasLaterBot'),
                          message: msg.content,
                          isActive: !hasLaterBot,
                        );
                      }
                      final isLastBot = !state.messages.sublist(index + 1).any((m) => m.isBot);
                      return KeyedSubtree(
                        key: ValueKey('${msg.id}_$isLastBot'),
                        child: _botMsg(msg, isLast: isLastBot),
                      );
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

/// Loads a photo thumbnail asynchronously using the download endpoint.
class _PhotoThumbLoader extends StatefulWidget {
  final String photoId;
  final dynamic dio;
  const _PhotoThumbLoader({required this.photoId, required this.dio});

  @override
  State<_PhotoThumbLoader> createState() => _PhotoThumbLoaderState();
}

class _PhotoThumbLoaderState extends State<_PhotoThumbLoader> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final resp = await widget.dio.get('/hierarchical/photos/${widget.photoId}/download');
      final data = resp.data as Map<String, dynamic>;
      final b64 = data['base64Content'] as String? ?? '';
      if (b64.isNotEmpty && mounted) {
        setState(() {
          _bytes = base64Decode(b64);
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (_bytes == null) {
      return const Center(child: Icon(Icons.broken_image, size: 28, color: Color(0xFF9CA3AF)));
    }
    return Image.memory(_bytes!, fit: BoxFit.cover);
  }
}
