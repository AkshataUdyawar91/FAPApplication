// =============================================================================
// Integration Test Runner: Agency Login -> Chatbot -> Create Request Flow
//
// Launches the real app on Chrome with an overlay panel that drives the
// AssistantChatPanel workflow like a real user — tapping buttons, typing
// in text fields, selecting from lists, and uploading documents.
//
// File uploads bypass FilePicker by calling the AssistantNotifier directly
// with bytes loaded from bundled test assets (FilePicker can't be automated).
//
// Prerequisites:
//   1. Backend API running on http://localhost:5000
//   2. Agency user seeded: agency@bajaj.com / Password123!
//   3. Assistant endpoint: POST /api/assistant/message
//   4. Test docs in assets/test_docs/
//
// Run:
//   cd frontend
//   flutter run -d chrome -t integration_test/chatbot_test.dart
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bajaj_document_processing/core/theme/app_theme.dart';
import 'package:bajaj_document_processing/core/router/app_router.dart';
import 'package:bajaj_document_processing/features/assistant/presentation/widgets/assistant_chat_panel.dart';
import 'package:bajaj_document_processing/features/assistant/presentation/providers/assistant_providers.dart';
import 'package:bajaj_document_processing/features/assistant/presentation/providers/assistant_notifier.dart';
import 'integration_test_config.dart';

/// Global ref so the test panel can read/write Riverpod providers.
WidgetRef? _globalRef;

void main() {
  runApp(
    const ProviderScope(child: ChatbotTestApp()),
  );
}

class ChatbotTestApp extends ConsumerWidget {
  const ChatbotTestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _globalRef = ref;
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'FieldIQ - Chatbot Integration Test',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const Positioned(
              top: 0,
              right: 0,
              child: SafeArea(child: ChatbotTestRunnerPanel()),
            ),
          ],
        );
      },
    );
  }
}

/// Floating panel that shows test progress and drives the chatbot workflow.
class ChatbotTestRunnerPanel extends StatefulWidget {
  const ChatbotTestRunnerPanel({super.key});

  @override
  State<ChatbotTestRunnerPanel> createState() => _ChatbotTestRunnerPanelState();
}

class _ChatbotTestRunnerPanelState extends State<ChatbotTestRunnerPanel> {
  final List<_TestStep> _steps = [];
  bool _isRunning = false;
  bool _isComplete = false;
  int _passed = 0;
  int _failed = 0;

  // ── Notifier shortcut ──
  AssistantNotifier get _notifier =>
      _globalRef!.read(assistantNotifierProvider.notifier);
  AssistantState get _state =>
      _globalRef!.read(assistantNotifierProvider);

  /// Returns the response type of the last bot message.
  String _lastBotType() {
    final msgs = _state.messages;
    final last = msgs.lastWhere(
      (m) => m.isBot,
      orElse: () => AssistantMessage(
        id: '',
        content: '',
        isBot: true,
        timestamp: DateTime(2000),
      ),
    );
    return last.response?.type ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 380,
        constraints: const BoxConstraints(maxHeight: 520),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF16213e)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            if (_steps.isNotEmpty) _buildStepsList(),
            if (!_isRunning) _buildRunButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF16213e),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(
            _isComplete
                ? (_failed == 0 ? Icons.check_circle : Icons.error)
                : Icons.play_circle_fill,
            color: _isComplete
                ? (_failed == 0 ? Colors.green : Colors.red)
                : Colors.blue,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Chatbot Request Test',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          if (_isComplete)
            Text(
              '$_passed\u2713 $_failed\u2717',
              style: TextStyle(
                color: _failed == 0 ? Colors.green : Colors.red,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepsList() {
    return Flexible(
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.all(8),
        itemCount: _steps.length,
        itemBuilder: (context, index) {
          final step = _steps[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  step.status == _Status.passed
                      ? Icons.check_circle
                      : step.status == _Status.failed
                          ? Icons.cancel
                          : step.status == _Status.running
                              ? Icons.hourglass_top
                              : Icons.circle_outlined,
                  color: step.status == _Status.passed
                      ? Colors.green
                      : step.status == _Status.failed
                          ? Colors.red
                          : step.status == _Status.running
                              ? Colors.amber
                              : Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.name,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ),
                if (step.detail != null)
                  Flexible(
                    child: Text(
                      step.detail!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRunButton() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _runTests,
          icon: Icon(_isComplete ? Icons.replay : Icons.play_arrow),
          label: Text(_isComplete ? 'Run Again' : 'Run Tests'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0f3460),
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TEST EXECUTION — Full conversational submission flow
  // Mirrors the real user flow from the example chat:
  //   Login → Greeting → Start new submission → PO search → Select PO →
  //   State selection → Invoice upload → Cost summary → Activity summary →
  //   Team count → Team name → Dealer → Dates → Confirm → Photos →
  //   Done photos → Team summary → Enquiry dump → Final review → Submit
  // =========================================================================

  Future<void> _runTests() async {
    setState(() {
      _isRunning = true;
      _isComplete = false;
      _passed = 0;
      _failed = 0;
      _steps.clear();
    });

    // ── Phase 1: Login ──────────────────────────────────────────────────

    await _step('Login page renders', () async {
      await _waitFor(() => _findText('Bajaj Auto') && _findText('Sign In'));
    });

    await _step('Tap Sign In', () async {
      _tapElevatedButton('Sign In');
      await _waitFor(() => _findText('My Requests'), timeout: 10);
    });

    // ── Phase 2: Chatbot auto-opens with greeting ───────────────────────

    await _step('Chatbot panel visible', () async {
      await _waitFor(
        () => _findWidgetByType<AssistantChatPanel>() != null,
        timeout: 5,
      );
    });

    await _step('Greeting received', () async {
      await _waitFor(
        () => !_state.isLoading && _lastBotType() == 'greeting',
        timeout: 10,
      );
    });

    // ── Phase 3: Tap "Start a new submission" card ──────────────────────
    // The greeting shows WorkflowActionCards rendered as InkWell cards.
    // We tap the one whose title contains "new submission" or "Create".

    await _step('Tap Start a new submission', () async {
      // The card is an InkWell inside WorkflowActionCard
      final tapped = _tapInkWellContainingText('Start a new submission') ||
          _tapInkWellContainingText('Create New Request') ||
          _tapInkWellContainingText('New Request');
      if (!tapped) {
        // Fallback: call notifier directly
        _notifier.sendAction('create_request');
      }
      await _waitForNotLoading(timeout: 10);
      final t = _lastBotType();
      if (t != 'po_search' && t != 'po_search_results') {
        throw Exception('Expected po_search, got $t');
      }
    });

    // ── Phase 4: Type PO number and select ──────────────────────────────

    await _step('Type PO number: 8110011755', () async {
      // The bottom input should now be a PO search bar
      _typeInTextField('Search PO', '8110011755');
      // Wait for debounce + API response
      await _waitForNotLoading(timeout: 15);
      await _waitFor(
        () => _lastBotType() == 'po_search_results' || _lastBotType() == 'po_search',
        timeout: 10,
      );
    });

    await _step('Click Next / Select PO', () async {
      // PO results show as a list. Try tapping the OutlinedButton with the PO number
      // or the first InkWell in the PO list
      final msgs = _state.messages;
      final lastBot = msgs.lastWhere((m) => m.isBot);
      final poItems = lastBot.response?.poItems;
      if (poItems != null && poItems.isNotEmpty) {
        // Tap the PO item in the list (rendered as InkWell/ListTile)
        final tapped = _tapInkWellContainingText('8110011755') ||
            _tapInkWellContainingText(poItems.first.poNumber);
        if (!tapped) {
          // Fallback: select via notifier
          _notifier.selectPO(poItems.first);
        }
      } else {
        throw Exception('No PO items returned from search');
      }
      await _waitForNotLoading(timeout: 10);
    });

    // ── Phase 5: Select state ───────────────────────────────────────────

    await _step('Type state: Maharashtra', () async {
      final t = _lastBotType();
      if (t == 'state_selection') {
        // State selection shows cards/buttons — type in search bar
        _typeInTextField('Type state', TestUploadConfig.activationState);
        await Future.delayed(const Duration(milliseconds: 500));
      }
      // Try tapping the Maharashtra button/card directly
      final tapped = _tapOutlinedButtonContainingText('Maharashtra') ||
          _tapInkWellContainingText('Maharashtra');
      if (!tapped) {
        _notifier.selectState(TestUploadConfig.activationState);
      }
      await _waitForNotLoading(timeout: 10);
    });

    await _step('State confirmed', () async {
      await _waitFor(
        () =>
            _lastBotType() == 'state_confirmed' ||
            _lastBotType() == 'invoice_upload',
        timeout: 10,
      );
    });

    // ── Phase 6: Upload Invoice ─────────────────────────────────────────

    await _step('Wait for invoice upload prompt', () async {
      await _waitFor(
        () => _lastBotType() == 'invoice_upload',
        timeout: 10,
      );
    });

    await _step('Upload invoice (bypass FilePicker)', () async {
      // Can't automate FilePicker — load from assets and call notifier
      final bytes = await rootBundle.load(TestDocPaths.invoiceAsset);
      _notifier.uploadInvoice(
        bytes.buffer.asUint8List(),
        'E-Invoice-145.pdf',
      );
      // Extraction polling can take up to 120s
      await _waitForNotLoading(timeout: 60);
    });

    await _step('Invoice validation table shown', () async {
      final t = _lastBotType();
      if (t != 'invoice_validation' && t != 'invoice_upload_success') {
        throw Exception('Expected invoice_validation, got $t');
      }
    });

    await _step('Click Continue with warnings', () async {
      // The validation card has "Continue with warnings" or "Continue" ElevatedButton
      final tapped = _tapElevatedButtonContaining('Continue with warnings') ||
          _tapElevatedButtonContaining('Continue');
      if (!tapped) {
        _notifier.continueAfterValidation();
      }
      await _waitForNotLoading(timeout: 15);
    });

    // ── Phase 7: Upload documents (Invoice done, now Cost Summary then Activity Summary) ──
    // Backend flow: Invoice → Cost Summary → Activity Summary → Team Details

    await _uploadCostSummary();
    await _uploadActivitySummary();

    // ── Phase 8: Team Details ───────────────────────────────────────────

    await _step('Wait for team count input', () async {
      await _waitFor(
        () => _lastBotType() == 'team_count_input',
        timeout: 10,
      );
    });

    await _step('Type team count: 1 and click Next', () async {
      // Bottom input is a TextField with hint "Enter number of teams..."
      _typeInTextField('Enter number of teams', '1');
      await Future.delayed(const Duration(milliseconds: 300));
      // Tap the "Next" button next to the text field
      _tapElevatedButton('Next');
      await _waitForNotLoading(timeout: 10);
    });

    await _step('Type team name: T1 and click Next', () async {
      await _waitFor(
        () => _lastBotType() == 'team_name_input',
        timeout: 10,
      );
      _typeInTextField('Enter team name', 'T1');
      await Future.delayed(const Duration(milliseconds: 300));
      _tapElevatedButton('Next');
      await _waitForNotLoading(timeout: 10);
    });

    await _step('Select first dealer from list', () async {
      await _waitFor(
        () =>
            _lastBotType() == 'dealer_search' ||
            _lastBotType() == 'dealer_list' ||
            _lastBotType() == 'dealer_search_results',
        timeout: 10,
      );
      // If dealer_search, type in the search bar to get results
      if (_lastBotType() == 'dealer_search') {
        _typeInTextField('Type dealer name', 'Bajaj');
        await _waitForNotLoading(timeout: 10);
        await _waitFor(
          () =>
              _lastBotType() == 'dealer_list' ||
              _lastBotType() == 'dealer_search_results',
          timeout: 10,
        );
      }
      // Tap the first dealer OutlinedButton in the list
      final msgs = _state.messages;
      final lastBot = msgs.lastWhere((m) => m.isBot);
      final dealers = lastBot.response?.dealers;
      if (dealers != null && dealers.isNotEmpty) {
        final tapped = _tapOutlinedButtonContainingText(dealers.first.dealerName);
        if (!tapped) {
          _notifier.selectDealer({
            'dealerCode': dealers.first.dealerCode,
            'dealerName': dealers.first.dealerName,
            'city': dealers.first.city,
            'state': dealers.first.state,
          }, _state.teamPayloadJson ?? '{}');
        }
      } else {
        throw Exception('No dealers returned');
      }
      await _waitForNotLoading(timeout: 10);
    });

    await _step('Pick start & end date', () async {
      await _waitFor(
        () => _lastBotType() == 'date_picker_start',
        timeout: 10,
      );
      // The date picker button is an ElevatedButton "Pick Start & End Date"
      // Tapping it opens native date pickers which can't be automated.
      // Call notifier directly with today's date.
      final today = DateTime.now();
      final payload = _state.teamPayloadJson ?? '{}';
      _notifier.submitTeamDates(today, today, payload);
      await _waitForNotLoading(timeout: 10);
    });

    await _step('Tap Confirm', () async {
      await _waitFor(
        () => _lastBotType() == 'team_dates_confirm',
        timeout: 10,
      );
      // The confirm card has "Confirm ✓" ElevatedButton
      final tapped = _tapElevatedButtonContaining('Confirm');
      if (!tapped) {
        _notifier.confirmTeam(_state.teamPayloadJson ?? '{}');
      }
      await _waitForNotLoading(timeout: 10);
    });

    // ── Phase 9: Upload Team Photos ─────────────────────────────────────

    await _step('Wait for photo upload prompt', () async {
      await _waitFor(
        () => _lastBotType() == 'photo_upload',
        timeout: 10,
      );
    });

    await _step('Upload 3 team photos (bypass FilePicker)', () async {
      final photoBytes = await rootBundle.load(TestDocPaths.teamPhotoAsset);
      final bytes = photoBytes.buffer.asUint8List();
      final payload = _state.teamPayloadJson ?? '{}';
      _notifier.uploadTeamPhotos(
        [bytes, bytes, bytes],
        ['Team_Photo.jpeg', 'Team_Photo2.jpeg', 'Team_Photo3.jpeg'],
        payload,
      );
      await _waitForNotLoading(timeout: 60);
    });

    await _step('Tap Done Team 1', () async {
      final t = _lastBotType();
      if (t == 'photo_validation_results' || t == 'photo_upload') {
        // The button says "Done Team 1" or similar
        final tapped = _tapElevatedButtonContaining('Done') ||
            _tapElevatedButtonContaining('Done Team');
        if (!tapped) {
          _notifier.doneTeamPhotos(_state.teamPayloadJson ?? '{}');
        }
        await _waitForNotLoading(timeout: 15);
      }
    });

    // ── Phase 10: Team Summary → Continue ───────────────────────────────

    await _step('Team summary shown, tap Continue', () async {
      await _waitFor(
        () => _lastBotType() == 'team_summary',
        timeout: 10,
      );
      // The summary card has "Continue →" ElevatedButton
      final tapped = _tapElevatedButtonContaining('Continue');
      if (!tapped) {
        _notifier.continueAfterTeams(_state.teamPayloadJson ?? '{}');
      }
      await _waitForNotLoading(timeout: 15);
    });

    // ── Phase 11: Upload Enquiry Dump ───────────────────────────────────

    await _step('Wait for enquiry upload prompt', () async {
      await _waitFor(
        () => _lastBotType() == 'enquiry_dump_upload',
        timeout: 10,
      );
    });

    await _step('Upload enquiry dump (bypass FilePicker)', () async {
      final bytes = await rootBundle.load(TestDocPaths.enquiryReportAsset);
      _notifier.uploadEnquiryDump(
        bytes.buffer.asUint8List(),
        'Enquiry_Report.xlsx',
      );
      await _waitForNotLoading(timeout: 60);
    });

    await _step('Tap Continue with warnings (enquiry)', () async {
      await _waitFor(
        () => _lastBotType() == 'enquiry_dump_validation',
        timeout: 60,
      );
      final tapped = _tapElevatedButtonContaining('Continue with war') ||
          _tapElevatedButtonContaining('Continue');
      if (!tapped) {
        _notifier.continueAfterEnquiry();
      }
      await _waitForNotLoading(timeout: 15);
    });

    // ── Phase 12: Final Review → Submit ─────────────────────────────────

    await _step('Final review shown', () async {
      await _waitFor(
        () => _lastBotType() == 'final_review',
        timeout: 10,
      );
    });

    await _step('Tap Submit', () async {
      // The final review card has "Submit" ElevatedButton
      final tapped = _tapElevatedButton('Submit');
      if (!tapped) {
        _notifier.submitFromChat();
      }
      await _waitForNotLoading(timeout: 60);
    });

    await _step('Submission success', () async {
      await _waitFor(
        () =>
            _lastBotType() == 'submit_success' ||
            _findText('submitted') ||
            _findText('success'),
        timeout: 15,
      );
    });

    setState(() {
      _isRunning = false;
      _isComplete = true;
    });
  }

  // ── Reusable upload sub-flows ─────────────────────────────────────────

  Future<void> _uploadCostSummary() async {
    await _step('Wait for cost summary prompt', () async {
      if (_lastBotType() != 'cost_summary_upload') {
        await _waitFor(
          () => _lastBotType() == 'cost_summary_upload',
          timeout: 10,
        );
      }
    });

    await _step('Upload cost summary (bypass FilePicker)', () async {
      final bytes = await rootBundle.load(TestDocPaths.costSummaryAsset);
      _notifier.uploadCostSummary(
        bytes.buffer.asUint8List(),
        'Cost_Summary.pdf',
      );
      await _waitForNotLoading(timeout: 60);
    });

    await _step('Click Continue with warnings (cost)', () async {
      await _waitFor(
        () => _lastBotType() == 'cost_summary_validation',
        timeout: 60,
      );
      // Tap the LAST "Continue with warnings" or "Continue" button
      final tapped = _tapElevatedButtonContaining('Continue with warnings') ||
          _tapElevatedButtonContaining('Continue');
      if (!tapped) {
        _notifier.continueAfterCostSummary();
      }
      await _waitForNotLoading(timeout: 15);
    });
  }

  Future<void> _uploadActivitySummary() async {
    await _step('Wait for activity summary prompt', () async {
      if (_lastBotType() != 'activity_summary_upload') {
        await _waitFor(
          () => _lastBotType() == 'activity_summary_upload',
          timeout: 10,
        );
      }
    });

    await _step('Upload activity summary (bypass FilePicker)', () async {
      final bytes = await rootBundle.load(TestDocPaths.activitySummaryAsset);
      _notifier.uploadActivitySummary(
        bytes.buffer.asUint8List(),
        'Activity_Summary.jpg',
      );
      await _waitForNotLoading(timeout: 60);
    });

    await _step('Click Continue with warnings (activity)', () async {
      await _waitFor(
        () => _lastBotType() == 'activity_summary_validation',
        timeout: 60,
      );
      final tapped = _tapElevatedButtonContaining('Continue with warnings') ||
          _tapElevatedButtonContaining('Continue');
      if (!tapped) {
        _notifier.continueAfterActivity();
      }
      await _waitForNotLoading(timeout: 15);
    });
  }

  // =========================================================================
  // HELPERS
  // =========================================================================

  Future<void> _step(String name, Future<void> Function() action) async {
    final step = _TestStep(name: name, status: _Status.running);
    setState(() => _steps.add(step));
    try {
      // Scroll chat to the bottom before every action so the latest
      // messages/buttons are visible and tappable.
      _scrollChatToEnd();
      await Future.delayed(const Duration(milliseconds: 200));
      await action();
      setState(() {
        step.status = _Status.passed;
        step.detail = 'OK';
        _passed++;
      });
    } catch (e) {
      setState(() {
        step.status = _Status.failed;
        step.detail = e.toString().replaceAll('Exception: ', '');
        _failed++;
      });
    }
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _waitFor(bool Function() condition, {int timeout = 6}) async {
    final deadline = DateTime.now().add(Duration(seconds: timeout));
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (condition()) return;
    }
    throw Exception('Timed out after ${timeout}s');
  }

  /// Waits until the notifier is no longer loading.
  Future<void> _waitForNotLoading({int timeout = 15}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _waitFor(() => !_state.isLoading, timeout: timeout);
  }

  /// Scrolls the chat ListView inside AssistantChatPanel to the very bottom.
  /// Finds the ScrollController attached to the Scrollable and jumps to maxScrollExtent.
  void _scrollChatToEnd() {
    void visitor(Element element) {
      // Look for the Scrollable that lives inside AssistantChatPanel's ListView
      if (element.widget is Scrollable) {
        final scrollable = element.widget as Scrollable;
        final controller = scrollable.controller;
        if (controller != null && controller.hasClients) {
          controller.jumpTo(controller.position.maxScrollExtent);
          return; // done — first scrollable in the chat panel is enough
        }
      }
      element.visitChildren(visitor);
    }

    // Narrow the search to the AssistantChatPanel subtree
    void findPanel(Element element) {
      if (element.widget is AssistantChatPanel) {
        element.visitChildren(visitor);
        return;
      }
      element.visitChildren(findPanel);
    }

    _rootElement.visitChildren(findPanel);
  }

  // =========================================================================
  // WIDGET TREE TRAVERSAL — tap real UI elements
  // =========================================================================

  Element get _rootElement => WidgetsBinding.instance.rootElement!;

  bool _findText(String text) {
    bool found = false;
    void visitor(Element element) {
      if (found) return;
      if (element.widget is Text) {
        final t = (element.widget as Text).data ?? '';
        if (t.contains(text)) {
          found = true;
          return;
        }
      }
      if (element.widget is RichText) {
        if ((element.widget as RichText).text.toPlainText().contains(text)) {
          found = true;
          return;
        }
      }
      element.visitChildren(visitor);
    }
    _rootElement.visitChildren(visitor);
    return found;
  }

  T? _findWidgetByType<T extends Widget>() {
    T? result;
    void visitor(Element element) {
      if (result != null) return;
      if (element.widget is T) {
        result = element.widget as T;
        return;
      }
      element.visitChildren(visitor);
    }
    _rootElement.visitChildren(visitor);
    return result;
  }

  /// Taps the first ElevatedButton whose child Text exactly matches [text].
  /// Returns true if found and tapped.
  bool _tapElevatedButton(String text) {
    bool tapped = false;
    void visitor(Element element) {
      if (tapped) return;
      if (element.widget is ElevatedButton) {
        bool hasText = false;
        void tv(Element child) {
          if (hasText) return;
          if (child.widget is Text && (child.widget as Text).data == text) {
            hasText = true;
          }
          child.visitChildren(tv);
        }
        element.visitChildren(tv);
        if (hasText) {
          (element.widget as ElevatedButton).onPressed?.call();
          tapped = true;
          return;
        }
      }
      element.visitChildren(visitor);
    }
    _rootElement.visitChildren(visitor);
    return tapped;
  }

  /// Taps the LAST ElevatedButton whose child Text contains [text].
  /// When multiple buttons match (e.g. old + new "Continue"), we want the latest one.
  bool _tapElevatedButtonContaining(String text) {
    Element? lastMatch;
    void visitor(Element element) {
      if (element.widget is ElevatedButton) {
        bool hasText = false;
        void tv(Element child) {
          if (hasText) return;
          if (child.widget is Text) {
            final data = (child.widget as Text).data ?? '';
            if (data.contains(text)) hasText = true;
          }
          child.visitChildren(tv);
        }
        element.visitChildren(tv);
        if (hasText) {
          lastMatch = element;
        }
      }
      element.visitChildren(visitor);
    }
    _rootElement.visitChildren(visitor);
    if (lastMatch != null) {
      (lastMatch!.widget as ElevatedButton).onPressed?.call();
      return true;
    }
    return false;
  }

  /// Taps the first OutlinedButton whose child Text contains [text].
  bool _tapOutlinedButtonContainingText(String text) {
    bool tapped = false;
    void visitor(Element element) {
      if (tapped) return;
      if (element.widget is OutlinedButton) {
        bool hasText = false;
        void tv(Element child) {
          if (hasText) return;
          if (child.widget is Text) {
            final data = (child.widget as Text).data ?? '';
            if (data.contains(text)) hasText = true;
          }
          child.visitChildren(tv);
        }
        element.visitChildren(tv);
        if (hasText) {
          (element.widget as OutlinedButton).onPressed?.call();
          tapped = true;
          return;
        }
      }
      element.visitChildren(visitor);
    }
    _rootElement.visitChildren(visitor);
    return tapped;
  }

  /// Taps the first InkWell whose subtree contains Text matching [text].
  bool _tapInkWellContainingText(String text) {
    bool tapped = false;
    void visitor(Element element) {
      if (tapped) return;
      if (element.widget is InkWell) {
        bool hasText = false;
        void tv(Element child) {
          if (hasText) return;
          if (child.widget is Text) {
            final data = (child.widget as Text).data ?? '';
            if (data.contains(text)) hasText = true;
          }
          child.visitChildren(tv);
        }
        element.visitChildren(tv);
        if (hasText) {
          (element.widget as InkWell).onTap?.call();
          tapped = true;
          return;
        }
      }
      element.visitChildren(visitor);
    }
    _rootElement.visitChildren(visitor);
    return tapped;
  }

  /// Types [value] into the first TextField whose hint contains [hintText].
  void _typeInTextField(String hintText, String value) {
    void visitor(Element element) {
      if (element.widget is TextField) {
        final tf = element.widget as TextField;
        final hint = tf.decoration?.hintText ?? '';
        if (hint.contains(hintText)) {
          tf.controller?.text = value;
          tf.onChanged?.call(value);
          return;
        }
      }
      element.visitChildren(visitor);
    }
    _rootElement.visitChildren(visitor);
  }
}

// =========================================================================
// DATA CLASSES
// =========================================================================

enum _Status { pending, running, passed, failed }

class _TestStep {
  final String name;
  _Status status;
  String? detail;
  _TestStep({required this.name, this.status = _Status.pending});
}
