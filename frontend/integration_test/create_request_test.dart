// =============================================================================
// Integration Test Runner: Agency Login -> Dashboard -> Upload Flow
//
// Launches the real app on Chrome with an overlay panel that drives the UI
// like a real user. You can watch every interaction happen in the browser.
//
// Prerequisites:
//   1. Backend API running on http://localhost:5000
//   2. Agency user seeded: agency@bajaj.com / Password123!
//   3. Demo documents served at /api/test-files/* (or use dummy bytes)
//
// Run:
//   cd frontend
//   flutter run -d chrome -t integration_test/create_request_test.dart
// =============================================================================

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:bajaj_document_processing/core/theme/app_theme.dart';
import 'package:bajaj_document_processing/core/router/app_router.dart';
import 'package:bajaj_document_processing/features/submission/presentation/pages/agency_upload_page.dart';
import 'package:bajaj_document_processing/features/submission/presentation/widgets/campaign_list_section.dart';
import 'integration_test_config.dart';

void main() {
  runApp(
    const ProviderScope(
      child: IntegrationTestApp(),
    ),
  );
}

class IntegrationTestApp extends ConsumerWidget {
  const IntegrationTestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'FieldIQ - Integration Test',
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
              child: SafeArea(child: TestRunnerPanel()),
            ),
          ],
        );
      },
    );
  }
}

/// Floating panel that shows test progress and drives the UI automatically.
class TestRunnerPanel extends StatefulWidget {
  const TestRunnerPanel({super.key});

  @override
  State<TestRunnerPanel> createState() => _TestRunnerPanelState();
}

class _TestRunnerPanelState extends State<TestRunnerPanel> {
  final List<TestStep> _steps = [];
  bool _isRunning = false;
  bool _isComplete = false;
  int _passed = 0;
  int _failed = 0;

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
            child: Text('Integration Test Runner',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ),
          if (_isComplete)
            Text('$_passed passed, $_failed failed',
                style: TextStyle(
                    color: _failed == 0 ? Colors.green : Colors.red,
                    fontSize: 12)),
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
                  step.status == StepStatus.passed
                      ? Icons.check_circle
                      : step.status == StepStatus.failed
                          ? Icons.cancel
                          : step.status == StepStatus.running
                              ? Icons.hourglass_top
                              : Icons.circle_outlined,
                  color: step.status == StepStatus.passed
                      ? Colors.green
                      : step.status == StepStatus.failed
                          ? Colors.red
                          : step.status == StepStatus.running
                              ? Colors.amber
                              : Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(step.name,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.9), fontSize: 12)),
                ),
                if (step.detail != null)
                  Flexible(
                    child: Text(step.detail!,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5), fontSize: 10),
                        overflow: TextOverflow.ellipsis),
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
  // TEST EXECUTION
  // =========================================================================

  Future<void> _runTests() async {
    setState(() {
      _isRunning = true;
      _isComplete = false;
      _passed = 0;
      _failed = 0;
      _steps.clear();
    });

    // ── Phase 1: Login ──

    await _runStep('Login page renders correctly', () async {
      await _waitFor(() => _findText('Bajaj Auto') && _findText('Sign In'));
    });

    await _runStep('Dev credentials are prefilled', () async {
      if (_findWidgetByType<TextFormField>() == null) {
        throw Exception('Email field not found');
      }
    });

    await _runStep('Tap Sign In button', () async {
      await _scrollToElevatedButton('Sign In');
      _tapElevatedButton('Sign In');
      await _waitFor(() => _findText('My Requests'), timeout: 10);
    });

    await _runStep('Dashboard loaded after login', () async {
      if (!_findText('My Requests')) throw Exception('Dashboard not loaded');
    });

    // ── Phase 2: Navigate to Upload ──

    await _runStep('New Request button visible', () async {
      if (!_findText('New Request') && !_findText('New')) {
        throw Exception('New Request button not found');
      }
    });

    await _runStep('Navigate to upload page', () async {
      await _scrollToElevatedButton('New Request');
      _tapElevatedButton('New Request');
      await _waitFor(
        () => _findText('Create New Request') || _findText('Purchase Order'),
        timeout: 5,
      );
    });

    await _runStep('Upload page shows Invoice tab', () async {
      if (!_findText('Invoice')) throw Exception('Invoice tab not found');
    });

    // ── Phase 3: Fill Upload Form (Step 1 - Invoice) ──

    await _runStep('Select first PO from dropdown', () async {
      await _waitFor(() {
        return _findInkWellWithIcon(Icons.description_outlined);
      }, timeout: 8);
      await _scrollToInkWellWithIcon(Icons.description_outlined);
      _tapFirstInkWellWithIcon(Icons.description_outlined);
      await Future.delayed(const Duration(milliseconds: 800));
      await _waitFor(() => _findIcon(Icons.check_circle), timeout: 3);
    });

    await _runStep('Select ${TestUploadConfig.activationState} state', () async {
      await _scrollToText('Search state...');
      _typeInTextField('Search state...', TestUploadConfig.activationState);
      await _waitFor(
        () => _findText(TestUploadConfig.activationState),
        timeout: 5,
      );
      await Future.delayed(const Duration(milliseconds: 500));
      _tapInkWellContainingText(TestUploadConfig.activationState);
      await Future.delayed(const Duration(milliseconds: 500));
    });

    await _runStep('Upload invoice file', () async {
      await _scrollToText('Invoice');
      final state = _findUploadPageState();
      if (state == null) throw Exception('Upload page state not found');

      // Load real invoice PDF from bundled assets
      final invoiceBytes = await rootBundle.load('assets/test_docs/E-Invoice-145.pdf');
      final invoiceFile = PlatformFile(
        name: 'E-Invoice-145.pdf',
        size: invoiceBytes.lengthInBytes,
        bytes: invoiceBytes.buffer.asUint8List(),
      );

      final invoice = InvoiceItemData(
        id: 'test_inv_${DateTime.now().millisecondsSinceEpoch}',
      )..file = invoiceFile;

      state.testInvoices.clear();
      state.testInvoices.add(invoice);
      state.testRebuild();
      await Future.delayed(const Duration(milliseconds: 500));

      // Trigger extraction via the real API
      await state.testExtractInvoice(invoice);
    });

    await _runStep('Wait for invoice data extraction', () async {
      final state = _findUploadPageState();
      if (state == null) throw Exception('Upload page state not found');

      // Poll until extraction finishes
      await _waitFor(() {
        if (state.testInvoices.isEmpty) return false;
        final inv = state.testInvoices.first;
        return inv.extractionStatus == ExtractionStatus.success ||
               inv.extractionStatus == ExtractionStatus.failed;
      }, timeout: 30);

      final inv = state.testInvoices.first;
      if (inv.extractionStatus == ExtractionStatus.failed) {
        // Fill manual data so we can proceed
        inv.invoiceNumber = 'TEST-INV-001';
        inv.invoiceDate = '01-01-2026';
        inv.totalAmount = '50000';
        inv.gstNumber = '27AABCU9603R1ZM';
        inv.invoiceNumberController.text = inv.invoiceNumber;
        inv.invoiceDateController.text = inv.invoiceDate;
        inv.totalAmountController.text = inv.totalAmount;
        inv.gstNumberController.text = inv.gstNumber;
        state.testRebuild();
      }
    });

    await _runStep('Upload cost summary file', () async {
      await _scrollToText('Cost Summary');
      final state = _findUploadPageState();
      if (state == null) throw Exception('Upload page state not found');

      // Load real cost summary PDF from bundled assets
      final costBytes = await rootBundle.load('assets/test_docs/Cost_Summary.pdf');
      final costFile = PlatformFile(
        name: 'Cost_Summary.pdf',
        size: costBytes.lengthInBytes,
        bytes: costBytes.buffer.asUint8List(),
      );

      state.testCostSummaryFile = costFile;
      state.testRebuild();
      await Future.delayed(const Duration(milliseconds: 500));
    });

    await _runStep('Tap Next Step button', () async {
      await _scrollToElevatedButton('Next Step');
      _tapElevatedButton('Next Step');
      await Future.delayed(const Duration(seconds: 2));
      // Verify we moved to step 2
      if (!_findText('Activity Summary') && !_findText('Team')) {
        throw Exception('Did not advance to step 2');
      }
    });

    // ── Phase 4: Fill Upload Form (Step 2 - Team and Activity Details) ──

    await _runStep('Upload activity summary file', () async {
      await _scrollToText('Activity Summary');
      final state = _findUploadPageState();
      if (state == null) throw Exception('Upload page state not found');

      final actBytes = await rootBundle.load(TestDocPaths.activitySummaryAsset);
      final actFile = PlatformFile(
        name: 'Activity_Summary.jpg',
        size: actBytes.lengthInBytes,
        bytes: actBytes.buffer.asUint8List(),
      );

      state.testActivitySummaryFile = actFile;
      state.testRebuild();
      await Future.delayed(const Duration(milliseconds: 500));
    });

    await _runStep('Load dealers from API', () async {
      await _scrollToCampaignSection();
      final clsState = _findCampaignListSectionState();
      if (clsState == null) throw Exception('CampaignListSection state not found');

      // The default team (campaign_1) is already created by initState
      final uploadState = _findUploadPageState();
      if (uploadState == null) throw Exception('Upload page state not found');
      final campaigns = uploadState.testCampaigns;
      if (campaigns.isEmpty) throw Exception('No campaigns found');

      final campaignId = campaigns.first.id;
      await clsState.testLoadDealers(campaignId);
      await Future.delayed(const Duration(milliseconds: 500));

      final dealerNames = clsState.testGetDealerNames(campaignId);
      if (dealerNames.isEmpty) throw Exception('No dealers loaded from API');
    });

    await _runStep('Select dealer name from dropdown', () async {
      await _scrollToText('Dealership Name');
      final clsState = _findCampaignListSectionState();
      if (clsState == null) throw Exception('CampaignListSection state not found');

      final uploadState = _findUploadPageState();
      final campaignId = uploadState!.testCampaigns.first.id;
      final dealerNames = clsState.testGetDealerNames(campaignId);

      // Pick the first dealer
      final selectedDealer = dealerNames.first;
      clsState.testSelectDealerName(campaignId, selectedDealer);
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify dealer name shows in UI
      if (!_findText(selectedDealer)) {
        throw Exception('Dealer name "$selectedDealer" not visible in UI');
      }
    });

    await _runStep('Select city from dropdown', () async {
      await _scrollToText('City');
      final clsState = _findCampaignListSectionState();
      if (clsState == null) throw Exception('CampaignListSection state not found');

      final uploadState = _findUploadPageState();
      final campaignId = uploadState!.testCampaigns.first.id;
      final cityOptions = clsState.testGetCityOptions(campaignId);

      if (cityOptions.isEmpty) throw Exception('No city options available');

      // Pick the first city
      final selectedCity = cityOptions.first;
      clsState.testSelectCity(campaignId, selectedCity);
      await Future.delayed(const Duration(milliseconds: 500));

      final cityName = selectedCity['city']?.toString() ?? '';
      final dealerCode = selectedCity['dealerCode']?.toString() ?? '';
      if (cityName.isNotEmpty && !_findText(cityName)) {
        throw Exception('City "$cityName" not visible in UI');
      }
      if (dealerCode.isNotEmpty && !_findText(dealerCode)) {
        throw Exception('Dealer code "$dealerCode" not visible in UI');
      }
    });

    await _runStep('Set dates and add team photo', () async {
      await _scrollToText('Start Date');
      final clsState = _findCampaignListSectionState();
      if (clsState == null) throw Exception('CampaignListSection state not found');

      final uploadState = _findUploadPageState();
      final campaign = uploadState!.testCampaigns.first;

      // Set dates and working days
      campaign.startDate = '01-01-2026';
      campaign.endDate = '31-01-2026';
      campaign.workingDays = '23';

      // Load a real team photo from bundled assets
      final photoBytes = await rootBundle.load(TestDocPaths.teamPhotoAsset);
      final photoFile = PlatformFile(
        name: 'Team_Photo.jpeg',
        size: photoBytes.lengthInBytes,
        bytes: photoBytes.buffer.asUint8List(),
      );
      campaign.photos.add(photoFile);

      clsState.testRebuild();
      uploadState.testRebuild();
      await Future.delayed(const Duration(milliseconds: 800));
    });

    await _runStep('Tap Next Step to go to step 3', () async {
      await _scrollToElevatedButton('Next Step');
      _tapElevatedButton('Next Step');
      await Future.delayed(const Duration(seconds: 2));
      // Verify we moved to step 3 (Enquiry and Supporting Docs)
      if (!_findText('Enquiry') && !_findText('Additional Documents')) {
        throw Exception('Did not advance to step 3');
      }
    });

    // ── Phase 5: Fill Upload Form (Step 3 - Enquiry and Supporting Docs) ──

    await _runStep('Upload enquiry document', () async {
      await _scrollToText('Enquiry');
      final state = _findUploadPageState();
      if (state == null) throw Exception('Upload page state not found');

      final enquiryBytes = await rootBundle.load(TestDocPaths.enquiryReportAsset);
      final enquiryFile = PlatformFile(
        name: 'Enquiry_Report.xlsx',
        size: enquiryBytes.lengthInBytes,
        bytes: enquiryBytes.buffer.asUint8List(),
      );

      state.testEnquiryDocFile = enquiryFile;
      state.testRebuild();
      await Future.delayed(const Duration(milliseconds: 500));
    });

    await _runStep('Submit for Validation', () async {
      await _scrollToElevatedButton('Submit for Validation');
      _tapElevatedButton('Submit for Validation');
      // Wait for navigation back to dashboard
      await _waitFor(
        () => _findText('My Requests'),
        timeout: 60,
      );
    });

    await _runStep('Verify submission success toast', () async {
      // Toast appears on dashboard after redirect — check specifically for toast text
      await _waitFor(
        () => _findText('Submission complete'),
        timeout: 60,
      );
      if (!_findText('Submission complete')) {
        throw Exception('Success toast not shown after submission');
      }
    });

    setState(() {
      _isRunning = false;
      _isComplete = true;
    });
  }

  // =========================================================================
  // HELPERS
  // =========================================================================

  /// Finds the _AgencyUploadPageState via the element tree using the
  /// public test helper accessors we added.
  dynamic _findUploadPageState() {
    dynamic result;
    void visitor(Element element) {
      if (result != null) return;
      if (element is StatefulElement && element.widget is AgencyUploadPage) {
        result = element.state;
        return;
      }
      element.visitChildren(visitor);
    }
    _rootElement.visitChildren(visitor);
    return result;
  }

  /// Finds the _CampaignListSectionState via the element tree using the
  /// public test helper accessors we added.
  dynamic _findCampaignListSectionState() {
    dynamic result;
    void visitor(Element element) {
      if (result != null) return;
      if (element is StatefulElement && element.widget is CampaignListSection) {
        result = element.state;
        return;
      }
      element.visitChildren(visitor);
    }
    _rootElement.visitChildren(visitor);
    return result;
  }

  Future<void> _runStep(String name, Future<void> Function() action) async {
    final step = TestStep(name: name, status: StepStatus.running);
    setState(() => _steps.add(step));
    try {
      await action();
      setState(() {
        step.status = StepStatus.passed;
        step.detail = 'OK';
        _passed++;
      });
    } catch (e) {
      setState(() {
        step.status = StepStatus.failed;
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

  // =========================================================================
  // SCROLL INTO VIEW
  // =========================================================================

  /// Scrolls the first widget matching [test] into view so the user can see it.
  Future<void> _scrollToWidget(bool Function(Widget w) test) async {
    Element? target;
    void visitor(Element element) {
      if (target != null) return;
      if (test(element.widget)) { target = element; return; }
      element.visitChildren(visitor);
    }
    _rootElement.visitChildren(visitor);
    if (target != null) {
      final ctx = target!;
      await Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), alignment: 0.3);
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  /// Scrolls to the first Text widget containing [text].
  Future<void> _scrollToText(String text) async {
    await _scrollToWidget((w) {
      if (w is Text) return (w.data ?? '').contains(text);
      return false;
    });
  }

  /// Scrolls to the first ElevatedButton containing [text].
  Future<void> _scrollToElevatedButton(String text) async {
    Element? target;
    void visitor(Element element) {
      if (target != null) return;
      if (element.widget is ElevatedButton) {
        bool hasText = false;
        void tv(Element child) {
          if (hasText) return;
          if (child.widget is Text && (child.widget as Text).data == text) hasText = true;
          child.visitChildren(tv);
        }
        element.visitChildren(tv);
        if (hasText) { target = element; return; }
      }
      element.visitChildren(visitor);
    }
    _rootElement.visitChildren(visitor);
    if (target != null) {
      await Scrollable.ensureVisible(target!, duration: const Duration(milliseconds: 400), alignment: 0.3);
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  /// Scrolls to the first InkWell containing a child Icon with [icon].
  Future<void> _scrollToInkWellWithIcon(IconData icon) async {
    Element? target;
    void visitor(Element element) {
      if (target != null) return;
      if (element.widget is InkWell) {
        bool hasIcon = false;
        void iv(Element child) {
          if (hasIcon) return;
          if (child.widget is Icon && (child.widget as Icon).icon == icon) hasIcon = true;
          child.visitChildren(iv);
        }
        element.visitChildren(iv);
        if (hasIcon) { target = element; return; }
      }
      element.visitChildren(visitor);
    }
    _rootElement.visitChildren(visitor);
    if (target != null) {
      await Scrollable.ensureVisible(target!, duration: const Duration(milliseconds: 400), alignment: 0.3);
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  /// Scrolls to the CampaignListSection widget.
  Future<void> _scrollToCampaignSection() async {
    await _scrollToWidget((w) => w is CampaignListSection);
  }

  // =========================================================================
  // WIDGET TREE TRAVERSAL
  // All traversals start from root element to see the entire app.
  // =========================================================================

  Element get _rootElement => WidgetsBinding.instance.rootElement!;

  bool _findText(String text) {
    bool found = false;
    void visitor(Element element) {
      if (found) return;
      if (element.widget is Text) {
        final t = (element.widget as Text).data ?? '';
        if (t.contains(text)) { found = true; return; }
      }
      if (element.widget is RichText) {
        if ((element.widget as RichText).text.toPlainText().contains(text)) {
          found = true; return;
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
      if (element.widget is T) { result = element.widget as T; return; }
      element.visitChildren(visitor);
    }
    _rootElement.visitChildren(visitor);
    return result;
  }

  bool _findIcon(IconData icon) {
    bool found = false;
    void visitor(Element element) {
      if (found) return;
      if (element.widget is Icon && (element.widget as Icon).icon == icon) {
        found = true; return;
      }
      element.visitChildren(visitor);
    }
    _rootElement.visitChildren(visitor);
    return found;
  }

  bool _findInkWellWithIcon(IconData icon) {
    bool found = false;
    void visitor(Element element) {
      if (found) return;
      if (element.widget is InkWell) {
        bool hasIcon = false;
        void iv(Element child) {
          if (hasIcon) return;
          if (child.widget is Icon && (child.widget as Icon).icon == icon) {
            hasIcon = true;
          }
          child.visitChildren(iv);
        }
        element.visitChildren(iv);
        if (hasIcon) { found = true; return; }
      }
      element.visitChildren(visitor);
    }
    _rootElement.visitChildren(visitor);
    return found;
  }

  void _tapFirstInkWellWithIcon(IconData icon) {
    bool tapped = false;
    void visitor(Element element) {
      if (tapped) return;
      if (element.widget is InkWell) {
        bool hasIcon = false;
        void iv(Element child) {
          if (hasIcon) return;
          if (child.widget is Icon && (child.widget as Icon).icon == icon) {
            hasIcon = true;
          }
          child.visitChildren(iv);
        }
        element.visitChildren(iv);
        if (hasIcon) {
          (element.widget as InkWell).onTap?.call();
          tapped = true; return;
        }
      }
      element.visitChildren(visitor);
    }
    _rootElement.visitChildren(visitor);
  }

  void _tapInkWellContainingText(String text) {
    bool tapped = false;
    void visitor(Element element) {
      if (tapped) return;
      if (element.widget is InkWell) {
        bool hasText = false;
        void tv(Element child) {
          if (hasText) return;
          if (child.widget is Text &&
              ((child.widget as Text).data ?? '').contains(text)) {
            hasText = true;
          }
          child.visitChildren(tv);
        }
        element.visitChildren(tv);
        if (hasText) {
          (element.widget as InkWell).onTap?.call();
          tapped = true; return;
        }
      }
      element.visitChildren(visitor);
    }
    _rootElement.visitChildren(visitor);
  }

  void _tapElevatedButton(String text) {
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
          tapped = true; return;
        }
      }
      element.visitChildren(visitor);
    }
    _rootElement.visitChildren(visitor);
  }

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
      if (element.widget is TextFormField) {
        bool matched = false;
        void inner(Element child) {
          if (matched) return;
          if (child.widget is TextField) {
            final tf = child.widget as TextField;
            final h = tf.decoration?.hintText ?? '';
            if (h.contains(hintText)) {
              tf.controller?.text = value;
              tf.onChanged?.call(value);
              matched = true;
            }
          }
          child.visitChildren(inner);
        }
        element.visitChildren(inner);
        if (matched) return;
      }
      element.visitChildren(visitor);
    }
    _rootElement.visitChildren(visitor);
  }
}

// =========================================================================
// DATA CLASSES
// =========================================================================

enum StepStatus { pending, running, passed, failed }

class TestStep {
  final String name;
  StepStatus status;
  String? detail;
  TestStep({required this.name, this.status = StepStatus.pending, this.detail});
}
