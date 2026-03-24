import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/widgets/app_sidebar.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../core/widgets/chat_side_panel.dart';
import '../../../../core/widgets/chat_end_drawer.dart';
import '../../../../core/widgets/nav_item.dart';
import '../../../../core/router/app_router.dart';
import '../widgets/campaign_list_section.dart';

class AgencyUploadPage extends ConsumerStatefulWidget {
  final String token;
  final String userName;
  final String?
      submissionId; // If provided, we're in edit mode for an existing submission
  /// Optional Dio override — used in tests to inject a mock client.
  final Dio? dio;

  const AgencyUploadPage({
    super.key,
    required this.token,
    required this.userName,
    this.submissionId,
    this.dio,
  });

  @override
  ConsumerState<AgencyUploadPage> createState() => _AgencyUploadPageState();
}

class _AgencyUploadPageState extends ConsumerState<AgencyUploadPage>
    with SingleTickerProviderStateMixin {
  late final Dio _dio;

  late final TabController _tabController;
  int _currentStep = 1;
  bool _isUploading = false;
  bool _isChatOpen = false;
  bool _isSidebarCollapsed = true;
  bool _isLoadingExisting = false;

  String? _currentPackageId;

  // PO search / dropdown state
  List<Map<String, dynamic>> _availablePOs = [];
  Map<String, dynamic>? _selectedPO;
  bool _isLoadingPOs = false;
  final _poSearchController = TextEditingController();

  // Indian states dropdown
  List<Map<String, dynamic>> _indianStates = [];
  String? _selectedActivationState;
  bool _isLoadingStates = false;
  final _stateSearchController = TextEditingController();
  List<Map<String, dynamic>> _filteredStates = [];

  PlatformFile? _purchaseOrder;
  String? _existingPOFileName; // Server-side PO file name for edit mode
  List<InvoiceItemData> _invoices = []; // Invoices linked to PO (package level)
  PlatformFile? _costSummaryFile;
  String? _existingCostSummaryFileName;
  PlatformFile? _activitySummaryFile;
  String? _existingActivitySummaryFileName;
  PlatformFile? _enquiryDocFile;
  String? _existingEnquiryDocFileName;
  List<PlatformFile> _additionalDocs = [];

  List<CampaignItemData> _campaigns = []; // Teams (independent of invoices)

  bool get _isEditMode => widget.submissionId != null;

  // ── Test helpers (used by integration_test_runner.dart) ──
  /// Exposes invoices list for test injection.
  List<InvoiceItemData> get testInvoices => _invoices;
  set testInvoices(List<InvoiceItemData> v) => _invoices = v;
  /// Exposes cost summary file for test injection.
  PlatformFile? get testCostSummaryFile => _costSummaryFile;
  set testCostSummaryFile(PlatformFile? v) => _costSummaryFile = v;
  /// Exposes activity summary file for test injection.
  PlatformFile? get testActivitySummaryFile => _activitySummaryFile;
  set testActivitySummaryFile(PlatformFile? v) => _activitySummaryFile = v;
  /// Exposes enquiry doc file for test injection.
  PlatformFile? get testEnquiryDocFile => _enquiryDocFile;
  set testEnquiryDocFile(PlatformFile? v) => _enquiryDocFile = v;
  /// Exposes campaigns list for test injection.
  List<CampaignItemData> get testCampaigns => _campaigns;
  set testCampaigns(List<CampaignItemData> v) => _campaigns = v;
  /// Triggers invoice extraction for a given invoice.
  Future<void> testExtractInvoice(InvoiceItemData inv) =>
      _uploadAndAutofillInvoice(inv);
  /// Triggers a UI rebuild.
  // ignore: invalid_use_of_protected_member
  void testRebuild() => setState(() {});

  static const int _totalSteps = 3;

  static const List<_TabMeta> _tabs = [
    _TabMeta(number: 1, title: 'Invoice'),
    _TabMeta(number: 2, title: 'Team and Activity Details'),
    _TabMeta(number: 3, title: 'Enquiry and Supporting Docs'),
  ];

  @override
  void initState() {
    super.initState();
    _dio = widget.dio ?? Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'))
      ..interceptors.add(PrettyDioLogger());
    _tabController = TabController(length: _totalSteps, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) return;
        setState(() => _currentStep = _tabController.index + 1);
      });
    if (_isEditMode) {
      _currentPackageId = widget.submissionId;
      _loadExistingSubmission();
    }
    _loadPOs();
    _loadIndianStates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _poSearchController.dispose();
    _stateSearchController.dispose();
    for (final inv in _invoices) {
      inv.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPOs({String? search}) async {
    setState(() => _isLoadingPOs = true);
    try {
      final response = await _dio.get(
        '/pos',
        queryParameters:
            search != null && search.isNotEmpty ? {'search': search} : null,
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _availablePOs =
              List<Map<String, dynamic>>.from(response.data as List);
        });
      }
    } catch (e) {
      debugPrint('Error loading POs: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPOs = false);
    }
  }

  Future<void> _loadIndianStates() async {
    setState(() => _isLoadingStates = true);
    try {
      final response = await _dio.get(
        '/pos/states',
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _indianStates =
              List<Map<String, dynamic>>.from(response.data as List);
        });
      }
    } catch (e) {
      debugPrint('Error loading states: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStates = false);
    }
  }

  /// Loads existing submission data for edit mode and pre-populates the wizard
  Future<void> _loadExistingSubmission() async {
    setState(() => _isLoadingExisting = true);
    try {
      final response = await _dio.get(
        '/submissions/${widget.submissionId}',
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );
      if (response.statusCode == 200 && mounted) {
        final data = response.data as Map<String, dynamic>;

        // Restore activation state
        _selectedActivationState = data['activationState']?.toString();

        // Extract PO data from documents
        final documents = data['documents'] as List? ?? [];
        final poDoc = documents.firstWhere(
          (d) => d['type']?.toString() == 'PO',
          orElse: () => null,
        );
        if (poDoc != null) {
          _existingPOFileName = poDoc['filename']?.toString();
          final extractedData = poDoc['extractedData'];
          if (extractedData != null) {
            Map<String, dynamic>? parsed;
            if (extractedData is String && extractedData.isNotEmpty) {
              parsed = _parseJsonString(extractedData);
            } else if (extractedData is Map) {
              parsed = Map<String, dynamic>.from(extractedData);
            }
            if (parsed != null) {
              // PO data loaded for edit mode reference (used by POFieldsSection if present)
            }
          }
        }

        // Extract package-level documents
        _existingCostSummaryFileName = data['costSummaryFileName']?.toString();
        _existingActivitySummaryFileName =
            data['activitySummaryFileName']?.toString();
        _existingEnquiryDocFileName = data['enquiryDocFileName']?.toString();

        // Extract invoices at package level (linked to PO)
        final invoicesData = data['invoices'] as List? ?? [];
        if (invoicesData.isEmpty) {
          // Fallback: check inside campaigns for legacy data
          final campaignsForInv = data['campaigns'] as List? ?? [];
          for (final c in campaignsForInv) {
            final campInvoices = c['invoices'] as List? ?? [];
            for (final inv in campInvoices) {
              _invoices.add(InvoiceItemData(
                id: inv['id']?.toString() ?? UniqueKey().toString(),
                invoiceNumber: inv['invoiceNumber']?.toString() ?? '',
                invoiceDate: _formatDateForField(inv['invoiceDate']),
                totalAmount: inv['totalAmount']?.toString() ?? '',
                gstNumber: inv['gstNumber']?.toString() ?? '',
                existingFileName: inv['fileName']?.toString(),
              ));
            }
          }
        } else {
          _invoices = invoicesData.map((inv) {
            return InvoiceItemData(
              id: inv['id']?.toString() ?? UniqueKey().toString(),
              invoiceNumber: inv['invoiceNumber']?.toString() ?? '',
              invoiceDate: _formatDateForField(inv['invoiceDate']),
              totalAmount: inv['totalAmount']?.toString() ?? '',
              gstNumber: inv['gstNumber']?.toString() ?? '',
              existingFileName: inv['fileName']?.toString(),
            );
          }).toList();
        }

        // Extract teams (independent of invoices)
        final campaigns = data['campaigns'] as List? ?? [];
        _campaigns = campaigns.map((c) {
          final campaignId = c['id']?.toString() ?? UniqueKey().toString();
          final photos = (c['photos'] as List? ?? []);
          final existingPhotoNames =
              photos.map((p) => p['fileName']?.toString() ?? '').toList();

          final campaign = CampaignItemData(
            id: campaignId,
            campaignName: c['campaignName']?.toString() ?? '',
            startDate: _formatDateForField(c['startDate']),
            endDate: _formatDateForField(c['endDate']),
            workingDays: c['workingDays']?.toString() ?? '',
            dealershipName: c['dealershipName']?.toString() ?? '',
            dealershipAddress: c['dealershipAddress']?.toString() ?? '',
          );
          campaign.existingPhotoFileNames =
              existingPhotoNames.where((n) => n.isNotEmpty).toList();

          return campaign;
        }).toList();

        setState(() => _isLoadingExisting = false);
      }
    } catch (e) {
      debugPrint('Error loading existing submission: $e');
      if (mounted) {
        setState(() => _isLoadingExisting = false);
        _showError('Failed to load submission data');
      }
    }
  }

  String _formatDateForField(dynamic dateValue) {
    if (dateValue == null) return '';
    try {
      final dt = DateTime.parse(dateValue.toString());
      return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
    } catch (_) {
      return dateValue.toString();
    }
  }

  // ─── FILE PICKERS ────────────────────────────────────────────────────
  static const _allowedExtensions = [
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'bmp',
    'tiff',
    'webp',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'csv',
    'ppt',
    'pptx',
  ];

  Future<void> _pickFile(Function(PlatformFile?) setter,
      {bool isPO = false}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: _allowedExtensions);
      if (result != null && result.files.isNotEmpty) {
        setter(result.files.first);
        setState(() {});
        if (isPO) {
          await _uploadAndExtractPO(result.files.first);
        }
      }
    } catch (e) {
      _showError('Failed to pick file');
    }
  }

  Future<void> _uploadAndExtractPO(PlatformFile file) async {
    if (file.bytes == null) return;
    try {
      // Use extract-only endpoint — does NOT create a package or DB entity.
      // The actual PO upload happens at submit time.
      final extractResponse = await _dio.post(
        '/documents/extract',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(file.bytes!, filename: file.name),
          'documentType': 'PO',
        }),
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );
      if (!mounted) return;
      if (extractResponse.statusCode == 200) {
        final extractedData = extractResponse.data['extractedData'];
        if (extractedData != null && extractedData is Map) {
          // Data extracted — trigger rebuild so PO fields section can display it
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Error extracting PO: $e');
      _showError('Failed to extract PO data. You can enter details manually.');
    }
  }


  /// Extracts invoice fields from the uploaded file using the extract-only endpoint.
  /// Does NOT require a packageId — extraction happens on a temp blob and returns immediately.
  Future<void> _uploadAndAutofillInvoice(InvoiceItemData invoice) async {
    if (invoice.file?.bytes == null) return;
    setState(() {
      invoice.isExtracting = true;
      invoice.extractionStatus = ExtractionStatus.extracting;
      invoice.extractionError = null;
    });
    try {
      final extractResponse = await _dio.post(
        '/documents/extract',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(invoice.file!.bytes!,
              filename: invoice.file!.name),
          'documentType': 'Invoice',
        }),
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );
      if (!mounted) return;
      if (extractResponse.statusCode == 200) {
        final extractedData = extractResponse.data['extractedData'];
        if (extractedData != null && extractedData is Map) {
          final data = Map<String, dynamic>.from(extractedData);
          if (data.isNotEmpty) {
            setState(() {
              invoice.invoiceNumber =
                  (data['InvoiceNumber'] ?? data['invoiceNumber'])
                          ?.toString() ??
                      invoice.invoiceNumber;
              invoice.totalAmount =
                  (data['TotalAmount'] ?? data['totalAmount'])?.toString() ??
                      invoice.totalAmount;
              invoice.gstNumber = (data['GSTNumber'] ??
                          data['gstNumber'] ??
                          data['GSTIN'] ??
                          data['gstin'])
                      ?.toString() ??
                  invoice.gstNumber;
              final rawDate = data['InvoiceDate'] ??
                  data['invoiceDate'] ??
                  data['Date'] ??
                  data['date'];
              if (rawDate != null)
                invoice.invoiceDate = _formatDateForField(rawDate);
              // Sync controllers so the TextFormFields reflect the new values
              invoice.invoiceNumberController.text = invoice.invoiceNumber;
              invoice.totalAmountController.text = invoice.totalAmount;
              invoice.gstNumberController.text = invoice.gstNumber;
              invoice.invoiceDateController.text = invoice.invoiceDate;
              invoice.extractionStatus = ExtractionStatus.success;
            });
            return;
          }
        }
        // Response OK but no data extracted
        setState(() {
          invoice.extractionStatus = ExtractionStatus.failed;
          invoice.extractionError =
              'Could not extract fields from this document';
        });
      } else {
        setState(() {
          invoice.extractionStatus = ExtractionStatus.failed;
          invoice.extractionError =
              'Extraction returned status ${extractResponse.statusCode}';
        });
      }
    } on DioException catch (e) {
      debugPrint('Invoice autofill DioException: $e');
      if (mounted) {
        final msg = e.response?.data?['error']?.toString() ??
            e.message ??
            'Network error';
        setState(() {
          invoice.extractionStatus = ExtractionStatus.failed;
          invoice.extractionError = msg;
        });
      }
    } catch (e) {
      debugPrint('Invoice autofill failed: $e');
      if (mounted) {
        setState(() {
          invoice.extractionStatus = ExtractionStatus.failed;
          invoice.extractionError =
              'Extraction failed. Please enter details manually.';
        });
      }
    } finally {
      if (mounted) setState(() => invoice.isExtracting = false);
    }
  }

  Map<String, dynamic> _parseJsonString(String jsonString) {
    try {
      if (jsonString.isEmpty) return {};
      final decoded = jsonDecode(jsonString);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {};
    } catch (e) {
      debugPrint('JSON parse error: $e');
      return {};
    }
  }

  Future<void> _pickAdditionalDocs() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _additionalDocs.addAll(result.files));
      }
    } catch (e) {
      _showError('Failed to pick documents');
    }
  }

  // ─── NAVIGATION ──────────────────────────────────────────────────────
  void _handleNext() {
    // Step 1: PO required
    if (_currentStep == 1 &&
        _purchaseOrder == null &&
        _existingPOFileName == null &&
        _selectedPO == null) {
      _showError('Please select a Purchase Order');
      return;
    }
    // Step 1: Activation state required
    if (_currentStep == 1 &&
        (_selectedActivationState == null ||
            _selectedActivationState!.isEmpty)) {
      _showError('Please select an Activation State');
      return;
    }
    // Step 1: At least one invoice required
    if (_currentStep == 1 && _invoices.isEmpty) {
      _showError('Please upload at least one Invoice');
      return;
    }
    // Step 1: Invoice fields required
    if (_currentStep == 1) {
      for (int i = 0; i < _invoices.length; i++) {
        final inv = _invoices[i];
        final label = _invoices.length > 1 ? 'Invoice ${i + 1}' : 'Invoice';
        if (inv.invoiceNumber.trim().isEmpty) {
          _showError('Please enter $label Number');
          return;
        }
        if (inv.invoiceDate.trim().isEmpty) {
          _showError('Please enter $label Date');
          return;
        }
        if (inv.totalAmount.trim().isEmpty) {
          _showError('Please enter $label Amount');
          return;
        }
        if (inv.gstNumber.trim().isEmpty) {
          _showError('Please enter GSTIN for $label');
          return;
        }
      }
    }
    // Step 1: Cost summary required
    if (_currentStep == 1 &&
        _costSummaryFile == null &&
        _existingCostSummaryFileName == null) {
      _showError('Please upload a Cost Summary');
      return;
    }
    // Step 2: Activity summary required
    if (_currentStep == 2 &&
        _activitySummaryFile == null &&
        _existingActivitySummaryFileName == null) {
      _showError('Please upload an Activity Summary');
      return;
    }
    // Step 2: at least one team required
    if (_currentStep == 2 && _campaigns.isEmpty) {
      _showError('Please add at least one team');
      return;
    }
    // Step 2: team field validation
    if (_currentStep == 2) {
      for (int i = 0; i < _campaigns.length; i++) {
        final team = _campaigns[i];
        final label = _campaigns.length > 1 ? 'Team ${i + 1}' : 'Team';
        if (team.campaignName.trim().isEmpty) {
          _showError('Please enter Dealer Code for $label');
          return;
        }
        if (team.dealershipName.trim().isEmpty) {
          _showError('Please enter Dealership Name for $label');
          return;
        }
        if (team.dealershipAddress.trim().isEmpty) {
          _showError('Please enter City for $label');
          return;
        }
        if (team.startDate.trim().isEmpty) {
          _showError('Please enter Start Date for $label');
          return;
        }
        if (team.endDate.trim().isEmpty) {
          _showError('Please enter End Date for $label');
          return;
        }
        if (team.workingDays.trim().isEmpty) {
          _showError('Please enter Working Days for $label');
          return;
        }
      }
    }
    if (_currentStep < _totalSteps) {
      setState(() => _currentStep++);
      _tabController.animateTo(_currentStep - 1);
    }
  }

  void _handleBack() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
      _tabController.animateTo(_currentStep - 1);
    }
  }

  void _navigateToDashboard() {
    context.go('/home');
  }

  Future<void> _handleSubmit() async {
    if (_purchaseOrder == null &&
        _existingPOFileName == null &&
        _selectedPO == null) {
      _showError('Please select or upload a Purchase Order');
      return;
    }
    if (_selectedActivationState == null || _selectedActivationState!.isEmpty) {
      _showError('Please select an Activation State');
      return;
    }
    if (_invoices.isEmpty) {
      _showError('Please upload at least one Invoice');
      return;
    }
    for (int i = 0; i < _invoices.length; i++) {
      final inv = _invoices[i];
      final label = _invoices.length > 1 ? 'Invoice ${i + 1}' : 'Invoice';
      if (inv.invoiceNumber.trim().isEmpty) {
        _showError('Please enter $label Number');
        return;
      }
      if (inv.invoiceDate.trim().isEmpty) {
        _showError('Please enter $label Date');
        return;
      }
      if (inv.totalAmount.trim().isEmpty) {
        _showError('Please enter $label Amount');
        return;
      }
      if (inv.gstNumber.trim().isEmpty) {
        _showError('Please enter GSTIN for $label');
        return;
      }
    }
    if (_costSummaryFile == null && _existingCostSummaryFileName == null) {
      _showError('Please upload a Cost Summary');
      return;
    }
    if (_enquiryDocFile == null && _existingEnquiryDocFileName == null) {
      _showError('Please upload Enquiry Document');
      return;
    }
    if (_activitySummaryFile == null &&
        _existingActivitySummaryFileName == null) {
      _showError('Please upload an Activity Summary');
      return;
    }
    // Validate minimum photos per team
    for (int i = 0; i < _campaigns.length; i++) {
      final campaign = _campaigns[i];
      final photoCount = campaign.photos.length + (campaign.existingPhotoFileNames?.length ?? 0);
      if (photoCount < CampaignItemData.minPhotos) {
        final teamLabel = campaign.dealershipName.isNotEmpty
            ? campaign.dealershipName
            : 'Team ${i + 1}';
        _showError('$teamLabel needs at least ${CampaignItemData.minPhotos} photos ($photoCount uploaded)');
        return;
      }
    }
    setState(() => _isUploading = true);
    try {
      String? packageId = _currentPackageId;

      if (!_isEditMode) {
        // Always create a fresh package for the current user when submitting via dropdown PO.
        // The PO's linked packageId is a seeded/template package — reusing it would assign
        // the submission to the wrong user and hide it from the dashboard.
        if (_selectedPO != null) {
          final createResp = await _dio.post(
            '/submissions',
            data: {
              'selectedPoId': _selectedPO!['id']?.toString(),
              'activityState': _selectedActivationState,
            },
            options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
          );
          if (createResp.statusCode == 200 || createResp.statusCode == 201) {
            packageId = (createResp.data['id'] ?? createResp.data['packageId'])
                ?.toString();
          }
        }
        // If PO was uploaded as a file, upload it now to create the package.
        if (packageId == null && _purchaseOrder?.bytes != null) {
          final poResponse = await _dio.post('/documents/upload',
              data: FormData.fromMap({
                'file': MultipartFile.fromBytes(_purchaseOrder!.bytes!,
                    filename: _purchaseOrder!.name),
                'documentType': 'PO',
              }),
              options: Options(
                  headers: {'Authorization': 'Bearer ${widget.token}'}));
          if (poResponse.statusCode == 200) {
            packageId = poResponse.data['packageId']?.toString();
          }
        }
        if (packageId == null) {
          _showError('Failed to create package — please select or upload a PO');
          return;
        }
      } else {
        // Edit mode: if a new PO was picked, upload it as replacement
        if (_purchaseOrder?.bytes != null) {
          await _dio.post(
            '/documents/upload',
            data: FormData.fromMap({
              'file': MultipartFile.fromBytes(_purchaseOrder!.bytes!,
                  filename: _purchaseOrder!.name),
              'documentType': 'PO',
              'packageId': packageId,
            }),
            options:
                Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
          );
        }
      }

      _showSuccess('Uploading documents...');

      // Upload invoices (linked to PO at package level)
      for (final invoice in _invoices) {
        if (invoice.file?.bytes != null) {
          await _dio.post(
            '/documents/upload',
            data: FormData.fromMap({
              'file': MultipartFile.fromBytes(invoice.file!.bytes!,
                  filename: invoice.file!.name),
              'documentType': 'Invoice',
              'packageId': packageId,
            }),
            options:
                Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
          );
        }
      }

      // Upload teams (independent of invoices)
      for (final campaign in _campaigns) {
        String? campaignId;

        if (_isEditMode &&
            campaign.id.isNotEmpty &&
            !campaign.id.startsWith('campaign_')) {
          campaignId = campaign.id;
        } else {
          final campaignResponse = await _dio.post(
            '/hierarchical/$packageId/campaigns',
            data: {
              'campaignName': campaign.campaignName,
              'teamCode': campaign.campaignName,
              'startDate': campaign.startDate.isNotEmpty ? _parseDate(campaign.startDate)?.toIso8601String() : null,
              'endDate': campaign.endDate.isNotEmpty ? _parseDate(campaign.endDate)?.toIso8601String() : null,
              'workingDays': campaign.workingDays.isNotEmpty ? int.tryParse(campaign.workingDays) : null,
              'dealershipName': campaign.dealershipName,
              'dealershipAddress': campaign.dealershipAddress,
              'state': _selectedActivationState,
            },
            options:
                Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
          );
          campaignId = campaignResponse.data['campaignId']?.toString();
          if (campaignId == null) {
            debugPrint('Failed to create team: ${campaign.campaignName}');
            continue;
          }
        }

        // Upload photos for this team
        if (campaign.photos.isNotEmpty) {
          final photoFiles = campaign.photos
              .where((p) => p.bytes != null)
              .map((p) => MultipartFile.fromBytes(p.bytes!, filename: p.name))
              .toList();
          if (photoFiles.isNotEmpty) {
            await _dio.post(
              '/hierarchical/$packageId/campaigns/$campaignId/photos',
              data: FormData.fromMap({'files': photoFiles}),
              options:
                  Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
            );
          }
        }
      }

      // Get a campaignId for cost/activity summary upload (API requires it even though they're package-level)
      String? anyCampaignId;
      if (_campaigns.isNotEmpty) {
        final firstCampaign = _campaigns.first;
        if (firstCampaign.id.isNotEmpty &&
            !firstCampaign.id.startsWith('campaign_')) {
          anyCampaignId = firstCampaign.id;
        } else {
          // Fetch from server
          try {
            final structureResp = await _dio.get(
              '/hierarchical/$packageId/structure',
              options:
                  Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
            );
            final serverCampaigns =
                structureResp.data['campaigns'] as List? ?? [];
            if (serverCampaigns.isNotEmpty) {
              anyCampaignId = serverCampaigns.first['campaignId']?.toString();
            }
          } catch (_) {}
        }
      }

      // Upload cost summary (package level)
      if (_costSummaryFile?.bytes != null && anyCampaignId != null) {
        await _dio.post(
          '/hierarchical/$packageId/campaigns/$anyCampaignId/cost-summary',
          data: FormData.fromMap({
            'file': MultipartFile.fromBytes(_costSummaryFile!.bytes!,
                filename: _costSummaryFile!.name),
          }),
          options:
              Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
        );
      }

      // Upload activity summary (package level)
      if (_activitySummaryFile?.bytes != null && anyCampaignId != null) {
        await _dio.post(
          '/hierarchical/$packageId/campaigns/$anyCampaignId/activity-summary',
          data: FormData.fromMap({
            'file': MultipartFile.fromBytes(_activitySummaryFile!.bytes!,
                filename: _activitySummaryFile!.name),
          }),
          options:
              Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
        );
      }

      // Upload enquiry document (package level)
      if (_enquiryDocFile?.bytes != null) {
        await _dio.post(
          '/hierarchical/$packageId/enquiry-doc',
          data: FormData.fromMap({
            'file': MultipartFile.fromBytes(_enquiryDocFile!.bytes!,
                filename: _enquiryDocFile!.name),
          }),
          options:
              Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
        );
      }

      // Upload additional documents
      for (final doc in _additionalDocs) {
        if (doc.bytes != null) {
          await _dio.post(
            '/documents/upload',
            data: FormData.fromMap({
              'file': MultipartFile.fromBytes(doc.bytes!, filename: doc.name),
              'documentType': 'AdditionalDocument',
              'packageId': packageId,
            }),
            options:
                Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
          );
        }
      }

      if (_isEditMode) {
        await _dio.patch(
          '/submissions/$packageId/resubmit',
          options:
              Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
        );
        _showSuccess('Submission resubmitted successfully!');
      } else {
        await _dio.post(
          '/submissions/$packageId/process-async',
          data: {'activityState': _selectedActivationState},
          options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
        );
        _showSuccess('Submission complete! Processing in background...');
      }

      if (mounted) _navigateToDashboard();
    } catch (e) {
      _showError('Failed to submit: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  DateTime? _parseDate(String dateStr) {
    try {
      if (dateStr.isEmpty) return null;
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return DateTime(
            int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.rejectedText),
      );

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.approvedText),
      );

  // ─── SHARED NAV ITEMS ────────────────────────────────────────────────
  List<NavItem> _getNavItems(BuildContext context) {
    return [
      NavItem(
          icon: Icons.dashboard,
          label: 'Home',
          onTap: _navigateToDashboard),
      NavItem(
          icon: Icons.upload_file,
          label: 'New Claim',
          isActive: true,
          onTap: () {}),
      NavItem(
        icon: Icons.notifications,
        label: 'Notifications',
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notifications coming soon')));
        },
      ),
      NavItem(
        icon: Icons.settings,
        label: 'Settings',
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings coming soon')));
        },
      ),
    ];
  }

  /// Full-width top bar with Bajaj branding — spans sidebar + content.
  Widget _buildTopBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF003087),
      child: Row(
        children: [
          const Icon(Icons.business, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          const Text(
            'Bajaj',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ─── BUILD ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final device = getDeviceType(width);
        final isMobile = device == DeviceType.mobile;

        return Scaffold(
          appBar: isMobile
              ? AppBar(
                  backgroundColor: const Color(0xFF1E3A8A),
                  title: Text(
                      _isEditMode ? 'Edit Submission' : 'Create New Request',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  iconTheme: const IconThemeData(color: Colors.white),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _navigateToDashboard,
                  ),
                  actions: [
                    Builder(
                      builder: (ctx) => IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                      ),
                    ),
                  ],
                )
              : null,
          drawer: isMobile
              ? AppDrawer(
                  userName: widget.userName,
                  userRole: 'Agency',
                  navItems: _getNavItems(context),
                  onLogout: () => handleLogout(context, ref),
                )
              : null,
          body: Column(
            children: [
              if (!isMobile) _buildTopBar(),
              Expanded(
                child: Row(
                  children: [
                    if (!isMobile)
                      AppSidebar(
                        userName: widget.userName,
                        userRole: 'Agency',
                        navItems: _getNavItems(context),
                        onLogout: () => handleLogout(context, ref),
                        isCollapsed: _isSidebarCollapsed,
                        onToggleCollapse: () => setState(
                            () => _isSidebarCollapsed = !_isSidebarCollapsed),
                      ),
                    Expanded(
                      child: Column(
                        children: [
                          if (!isMobile) _buildHeader(device),
                          Expanded(child: _buildContentArea(device, width)),
                        ],
                      ),
                    ),
                    if (_isChatOpen && !isMobile)
                      ChatSidePanel(
                        token: widget.token,
                        userName: widget.userName,
                        deviceType: device,
                        onClose: () => setState(() => _isChatOpen = false),
                      ),
                  ],
                ),
              ),
            ],
          ),
          endDrawer: isMobile
              ? ChatEndDrawer(token: widget.token, userName: widget.userName)
              : null,
          floatingActionButton: (_isChatOpen && !isMobile)
              ? null
              : Builder(
                  builder: (scaffoldContext) => Padding(
                    padding: const EdgeInsets.only(bottom: 16, right: 4),
                    child: FloatingActionButton(
                      onPressed: () {
                        if (isMobile) {
                          Scaffold.of(scaffoldContext).openEndDrawer();
                        } else {
                          setState(() => _isChatOpen = !_isChatOpen);
                        }
                      },
                      backgroundColor: AppColors.primary,
                      child: const Icon(Icons.smart_toy, color: Colors.white),
                    ),
                  ),
                ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }

  // ─── HEADER (tablet/desktop) ──────────────────────────────────────────
  Widget _buildHeader(DeviceType device) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: device == DeviceType.desktop ? 16 : 14,
        vertical: 10,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Text(_isEditMode ? 'Edit Submission' : 'Create New Request',
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827))),
    );
  }

  // ─── CONTENT AREA ────────────────────────────────────────────────────
  Widget _buildContentArea(DeviceType device, double width) {
    final pad =
        responsiveValue<double>(width, mobile: 10, tablet: 14, desktop: 16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tab bar sits inside a white card with bottom border
        Container(
          color: Colors.white,
          child: _buildTabBar(device),
        ),
        // Scrollable tab content
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: pad, vertical: pad * 0.6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildStepContent(device)),
                const SizedBox(height: 8),
                _buildActionButtons(device),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── TAB BAR ──────────────────────────────────────────────────────────
  Widget _buildTabBar(DeviceType device) {
    return TabBar(
      controller: _tabController,
      isScrollable: device == DeviceType.mobile,
      tabAlignment:
          device == DeviceType.mobile ? TabAlignment.start : TabAlignment.fill,
      indicatorColor: AppColors.primary,
      indicatorWeight: 3,
      labelColor: AppColors.primary,
      unselectedLabelColor: const Color(0xFF6B7280),
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle:
          const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      dividerColor: AppColors.border,
      tabs: _tabs.map((t) {
        final isComplete = _currentStep > t.number;
        return Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Numbered circle
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isComplete
                      ? const Color(0xFF16A34A)
                      : _currentStep == t.number
                          ? AppColors.primary
                          : const Color(0xFFE5E7EB),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isComplete
                      ? const Icon(Icons.check, color: Colors.white, size: 12)
                      : Text(
                          '${t.number}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _currentStep == t.number
                                ? Colors.white
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Text(t.title),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── STEP CONTENT ─────────────────────────────────────────────────────
  Widget _buildStepContent(DeviceType device) {
    if (_isLoadingExisting) {
      return const Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading submission data...',
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ));
    }
    switch (_currentStep) {
      case 1:
        return SingleChildScrollView(child: _buildInvoiceDetailsStep(device));
      case 2:
        return SingleChildScrollView(child: _buildTeamsStep(device));
      case 3:
        return SingleChildScrollView(child: _buildEnquiryStep(device));
      default:
        return const SizedBox();
    }
  }

  // ─── STEP 1: INVOICE DETAILS ──────────────────────────────────────────
  Widget _buildInvoiceDetailsStep(DeviceType device) {
    final isMobile = device == DeviceType.mobile;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Purchase Order section ──
          _buildSectionLabel(
              'Purchase Order', 'Select the PO assigned to your agency.',
              required: true),
          const SizedBox(height: 12),
          _buildPOSearchDropdown(device),
          const SizedBox(height: 24),

          // ── Activation State section ──
          _buildSectionLabel(
              'State', 'Select the state where the activation took place.',
              required: true),
          const SizedBox(height: 12),
          _buildStateDropdown(),
          const SizedBox(height: 24),

          // ── Invoice section ──
          _buildSectionLabel(
              'Invoice', 'Upload the invoice and enter key details.',
              required: true),
          const SizedBox(height: 12),
          ..._invoices.asMap().entries.map(
              (entry) => _buildInvoiceCard(entry.key, entry.value, device)),
          if (_invoices.isEmpty)
            _buildFileUploadCard(
              'Upload Invoice',
              'Upload the invoice document (PDF only)',
              Icons.receipt_long,
              null,
              () async {
                final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: _allowedExtensions);
                if (result != null && result.files.isNotEmpty) {
                  final invoice = InvoiceItemData(
                    id: 'invoice_${DateTime.now().millisecondsSinceEpoch}',
                  )..file = result.files.first;
                  setState(() => _invoices.add(invoice));
                  await _uploadAndAutofillInvoice(invoice);
                }
              },
              () {},
              device,
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _invoices.add(InvoiceItemData(
                id: 'invoice_${DateTime.now().millisecondsSinceEpoch}'))),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Invoice', style: TextStyle(fontSize: 13)),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.primary, padding: EdgeInsets.zero),
          ),
          const SizedBox(height: 24),

          // ── Cost Summary section ──
          _buildSectionLabel(
              'Cost Summary', 'Upload the cost breakdown document.',
              required: true),
          const SizedBox(height: 12),
          _buildFlatFileRow(
            file: _costSummaryFile,
            existingFileName: _existingCostSummaryFileName,
            onPick: () =>
                _pickFile((f) => setState(() => _costSummaryFile = f)),
            onRemove: () => setState(() => _costSummaryFile = null),
          ),
        ],
      ),
    );
  }

  /// PO search + dropdown — fetches from API, shows typeahead results.
  Widget _buildPOSearchDropdown(DeviceType device) {
    final selectedLabel = _selectedPO != null
        ? '${_selectedPO!['poNumber'] ?? ''} — ${_selectedPO!['vendorName'] ?? ''}'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Purchase Order',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151))),
            const Text(' *', style: TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        // Selected PO chip
        if (_selectedPO != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFF16A34A), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selectedLabel ?? '',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF15803D)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_selectedPO!['totalAmount'] != null)
                  Text(
                    '₹${_formatAmount(_selectedPO!['totalAmount'])}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w500),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedPO = null;
                    _currentPackageId = null;
                    _poSearchController.clear();
                  }),
                  child: const Icon(Icons.close,
                      size: 16, color: AppColors.rejectedText),
                ),
              ],
            ),
          )
        else ...[
          // Search field
          TextFormField(
            controller: _poSearchController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by PO number or vendor name...',
              hintStyle:
                  const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
              prefixIcon: _isLoadingPOs
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : const Icon(Icons.search,
                      color: AppColors.primary, size: 20),
              suffixIcon: _poSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _poSearchController.clear();
                        _loadPOs();
                      },
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5)),
              isDense: true,
            ),
            onChanged: (v) {
              setState(() {});
              Future.delayed(const Duration(milliseconds: 350), () {
                if (_poSearchController.text == v) _loadPOs(search: v);
              });
            },
          ),
          // Dropdown results
          if (_availablePOs.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _availablePOs.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.border),
                itemBuilder: (context, i) {
                  final po = _availablePOs[i];
                  final poNum = po['poNumber']?.toString() ?? '—';
                  final vendor = po['vendorName']?.toString() ?? '';
                  final amount =
                      po['totalAmount']; // ignore: unused_local_variable
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedPO = po;
                        _currentPackageId = po['packageId']?.toString();
                        _poSearchController.clear();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.description_outlined,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(poNum,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary)),
                                if (vendor.isNotEmpty)
                                  Text(vendor,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          // if (amount != null)
                          //   Text(
                          //     '₹${_formatAmount(amount)}',
                          //     style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                          //   ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else if (!_isLoadingPOs && _poSearchController.text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text('No POs found',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
          ],
        ],
      ],
    );
  }

  String _formatAmount(dynamic amount) {
    try {
      final num val = amount is num ? amount : num.parse(amount.toString());
      if (val >= 10000000) return '${(val / 10000000).toStringAsFixed(2)} Cr';
      if (val >= 100000) return '${(val / 100000).toStringAsFixed(2)} L';
      return val.toStringAsFixed(0);
    } catch (_) {
      return amount.toString();
    }
  }

  /// Activation State searchable dropdown — populated from API.
  Widget _buildStateDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Activation State',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151))),
            const Text(' *', style: TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        // Selected state chip
        if (_selectedActivationState != null &&
            _selectedActivationState!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFF16A34A), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedActivationState!,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF15803D)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedActivationState = null;
                    _stateSearchController.clear();
                    _filteredStates = [];
                  }),
                  child: const Icon(Icons.close,
                      size: 16, color: AppColors.rejectedText),
                ),
              ],
            ),
          )
        else ...[
          // Search field
          TextFormField(
            controller: _stateSearchController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search state...',
              hintStyle:
                  const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
              prefixIcon: _isLoadingStates
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : const Icon(Icons.search,
                      color: AppColors.primary, size: 20),
              suffixIcon: _stateSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _stateSearchController.clear();
                        setState(() => _filteredStates = []);
                      },
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5)),
              isDense: true,
            ),
            onChanged: (v) {
              setState(() {
                if (v.isEmpty) {
                  _filteredStates = [];
                } else {
                  _filteredStates = _indianStates
                      .where((s) => (s['stateName']?.toString() ?? '')
                          .toLowerCase()
                          .contains(v.toLowerCase()))
                      .toList();
                }
              });
            },
          ),
          // Dropdown results
          if (_filteredStates.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _filteredStates.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.border),
                itemBuilder: (context, i) {
                  final state = _filteredStates[i];
                  final name = state['stateName']?.toString() ?? '';
                  // final gst = state['gstPercentage']?.toString();
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedActivationState = name;
                        _stateSearchController.clear();
                        _filteredStates = [];
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(name,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                          ),
                          // if (gst != null)
                          //   Text(
                          //     'GST $gst%',
                          //     style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                          //   ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else if (_stateSearchController.text.isNotEmpty &&
              !_isLoadingStates) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text('No states found',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
          ],
        ],
      ],
    );
  }

  /// Flat section label matching the screenshot style.
  Widget _buildSectionLabel(String title, String subtitle,
      {bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827))),
            if (required)
              const Text(' *',
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 2),
        Text(subtitle,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ],
    );
  }

  /// Dashed upload row — shows filename + Replace when uploaded, or upload prompt when empty.
  Widget _buildFlatFileRow({
    required PlatformFile? file,
    required String? existingFileName,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    final displayName = file?.name ?? existingFileName;
    final hasFile = displayName != null;

    if (hasFile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF15803D))),
                  const SizedBox(height: 2),
                  const Text('Uploaded',
                      style: TextStyle(fontSize: 11, color: Color(0xFF16A34A))),
                ],
              ),
            ),
            TextButton(
              onPressed: onPick,
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('Replace', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppColors.border, width: 1.5, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Icon(Icons.cloud_upload_outlined,
                size: 32, color: AppColors.primary.withOpacity(0.5)),
            const SizedBox(height: 6),
            const Text('Click to upload',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary)),
            const SizedBox(height: 2),
            const Text('PDF, Word, Excel, Images supported',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  /// One invoice entry: file row + 2-col fields grid + remove button.
  /// One invoice entry: card with icon header + file upload + fields grid + remove button.
  Widget _buildInvoiceCard(
      int index, InvoiceItemData invoice, DeviceType device) {
    final isMobile = device == DeviceType.mobile;
    final pad = isMobile ? 20.0 : 24.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.border.withValues(alpha: 0.5), width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.receipt_long,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _invoices.length > 1
                            ? 'Invoice ${index + 1}'
                            : 'Invoice',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      const Text('Upload the invoice document (PDF only)',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (_invoices.length > 1)
                  IconButton(
                    onPressed: () => setState(() {
                      final removed = _invoices.removeAt(index);
                      removed.dispose();
                    }),
                    icon: const Icon(Icons.close,
                        color: AppColors.rejectedText, size: 20),
                    tooltip: 'Remove invoice',
                  ),
              ],
            ),
            const SizedBox(height: 20),
            // File upload area
            if (invoice.file == null && invoice.existingFileName == null)
              InkWell(
                onTap: () async {
                  final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: _allowedExtensions);
                  if (result != null && result.files.isNotEmpty) {
                    setState(() => invoice.file = result.files.first);
                    await _uploadAndAutofillInvoice(invoice);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  height: isMobile ? 120 : 140,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.03),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined,
                          size: 48,
                          color: AppColors.primary.withValues(alpha: 0.6)),
                      const SizedBox(height: 12),
                      const Text('Click to upload',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                      const SizedBox(height: 4),
                      const Text('PDF, Word, Excel, Images supported',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.approvedBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.approvedBorder, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.check_circle,
                          color: AppColors.approvedText, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice.file?.name ??
                                invoice.existingFileName ??
                                '',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.approvedText),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            invoice.file != null
                                ? '${(invoice.file!.size / 1024).toStringAsFixed(1)} KB'
                                : 'Already uploaded',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.approvedText
                                    .withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() {
                        invoice.file = null;
                        invoice.extractionStatus = ExtractionStatus.none;
                        invoice.extractionError = null;
                      }),
                      icon: const Icon(Icons.close,
                          color: AppColors.rejectedText, size: 24),
                      tooltip: 'Remove file',
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            // Extraction status banner
            if (invoice.extractionStatus == ExtractionStatus.extracting)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary))),
                    const SizedBox(width: 10),
                    const Expanded(
                        child: Text(
                            'Extracting invoice details... Fields will autofill when complete.',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500))),
                  ],
                ),
              )
            else if (invoice.extractionStatus == ExtractionStatus.success)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.approvedBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.approvedBorder),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 18, color: AppColors.approvedText),
                    SizedBox(width: 10),
                    Expanded(
                        child: Text(
                            'Fields auto-filled from document. Please verify before proceeding.',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.approvedText,
                                fontWeight: FontWeight.w500))),
                  ],
                ),
              )
            else if (invoice.extractionStatus == ExtractionStatus.failed)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: Color(0xFFEA580C)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(
                            invoice.extractionError ??
                                'Auto-extraction failed. Please enter details manually.',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFEA580C),
                                fontWeight: FontWeight.w500))),
                  ],
                ),
              ),
            // Fields grid
            if (isMobile) ...[
              _buildFlatField('Invoice Number', invoice.invoiceNumber,
                  (v) => invoice.invoiceNumber = v,
                  required: true, controller: invoice.invoiceNumberController,
                  enabled: !invoice.isExtracting),
              const SizedBox(height: 10),
              _buildFlatDateField('Invoice Date', invoice.invoiceDate,
                  (v) => invoice.invoiceDate = v,
                  required: true, controller: invoice.invoiceDateController,
                  enabled: !invoice.isExtracting),
              const SizedBox(height: 10),
              _buildFlatField('Invoice Amount', invoice.totalAmount,
                  (v) => invoice.totalAmount = v,
                  required: true, controller: invoice.totalAmountController,
                  enabled: !invoice.isExtracting),
              const SizedBox(height: 10),
              _buildFlatField(
                  'GSTIN', invoice.gstNumber, (v) => invoice.gstNumber = v,
                  required: true, controller: invoice.gstNumberController,
                  enabled: !invoice.isExtracting),
            ] else ...[
              Row(children: [
                Expanded(
                    child: _buildFlatField('Invoice Number',
                        invoice.invoiceNumber, (v) => invoice.invoiceNumber = v,
                        required: true,
                        controller: invoice.invoiceNumberController,
                        enabled: !invoice.isExtracting)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildFlatDateField('Invoice Date',
                        invoice.invoiceDate, (v) => invoice.invoiceDate = v,
                        required: true,
                        controller: invoice.invoiceDateController,
                        enabled: !invoice.isExtracting)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _buildFlatField('Invoice Amount',
                        invoice.totalAmount, (v) => invoice.totalAmount = v,
                        required: true,
                        controller: invoice.totalAmountController,
                        enabled: !invoice.isExtracting)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildFlatField('GSTIN', invoice.gstNumber,
                        (v) => invoice.gstNumber = v,
                        required: true,
                        controller: invoice.gstNumberController,
                        enabled: !invoice.isExtracting)),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  /// Flat labeled text field matching the screenshot style.
  /// When [controller] is provided it is used instead of [initialValue] so
  /// that programmatic updates (e.g. from extraction) are reflected in the UI.
  Widget _buildFlatField(String label, String value, Function(String) onChanged,
      {bool required = false, TextEditingController? controller, bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151))),
            if (required)
              const Text(' *',
                  style: TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? value : null,
          onChanged: enabled ? (v) => setState(() => onChanged(v)) : null,
          enabled: enabled,
          style: TextStyle(fontSize: 14, color: enabled ? null : const Color(0xFF9CA3AF)),
          decoration: InputDecoration(
            filled: !enabled,
            fillColor: !enabled ? const Color(0xFFF3F4F6) : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border)),
            disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5)),
            isDense: true,
          ),
        ),
      ],
    );
  }

  /// Flat date field with calendar picker — matches PO date style.
  Widget _buildFlatDateField(
      String label, String value, Function(String) onChanged,
      {bool required = false, TextEditingController? controller, bool enabled = true}) {
    // Use the provided controller, or create a temporary one for backward compat
    final ctrl = controller ?? TextEditingController(text: value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151))),
            if (required)
              const Text(' *',
                  style: TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          readOnly: true,
          enabled: enabled,
          controller: ctrl,
          style: TextStyle(fontSize: 14, color: enabled ? null : const Color(0xFF9CA3AF)),
          decoration: InputDecoration(
            hintText: 'dd-mm-yyyy',
            hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
            filled: !enabled,
            fillColor: !enabled ? const Color(0xFFF3F4F6) : null,
            suffixIcon: Icon(Icons.calendar_today,
                color: enabled ? AppColors.primary : const Color(0xFF9CA3AF), size: 18),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border)),
            disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5)),
            isDense: true,
          ),
          onTap: enabled ? () async {
            DateTime initial = DateTime.now();
            if (value.isNotEmpty) {
              final parsed = _parseDate(value);
              if (parsed != null) initial = parsed;
            }
            final picked = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme:
                      const ColorScheme.light(primary: AppColors.primary),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              final formatted =
                  '${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}';
              ctrl.text = formatted;
              setState(() => onChanged(formatted));
            }
          } : null,
        ),
      ],
    );
  }

  // ─── STEP 2: TEAMS ────────────────────────────────────────────────────
  Widget _buildTeamsStep(DeviceType device) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(device == DeviceType.mobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Activity Summary section ──
          _buildSectionLabel(
              'Activity Summary', 'Upload the activity summary document.',
              required: true),
          const SizedBox(height: 12),
          _buildFlatFileRow(
            file: _activitySummaryFile,
            existingFileName: _existingActivitySummaryFileName,
            onPick: () =>
                _pickFile((f) => setState(() => _activitySummaryFile = f)),
            onRemove: () => setState(() => _activitySummaryFile = null),
          ),
          const SizedBox(height: 28),

          // ── Teams section ──
          CampaignListSection(
            campaigns: _campaigns,
            onCampaignsChanged: (campaigns) =>
                setState(() => _campaigns = campaigns),
            token: widget.token,
            packageId: _currentPackageId,
            selectedActivationState: _selectedActivationState,
          ),
        ],
      ),
    );
  }

  // ─── STEP 3: ENQUIRY & ADDITIONAL DOCS ───────────────────────────────
  Widget _buildEnquiryStep(DeviceType device) {
    final isMobile = device == DeviceType.mobile;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Inquiry Document ──
          _buildSectionLabel('Enquiry Document',
              'Upload the enquiry dump with customer leads. This is mandatory.',
              required: true),
          const SizedBox(height: 12),
          _buildFlatFileRow(
            file: _enquiryDocFile,
            existingFileName: _existingEnquiryDocFileName,
            onPick: () => _pickFile((f) => setState(() => _enquiryDocFile = f)),
            onRemove: () => setState(() => _enquiryDocFile = null),
          ),
          const SizedBox(height: 28),

          // ── Additional Documents ──
          _buildSectionLabel('Additional Documents',
              'Upload any other supporting documents (optional).'),
          const SizedBox(height: 12),
          _buildAdditionalDocsUploadArea(),
        ],
      ),
    );
  }

  Widget _buildAdditionalDocsUploadArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _pickAdditionalDocs,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
                width: 1.5,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Click to upload additional documents',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'PDF, Word, Excel, Images — max 50MB',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        if (_additionalDocs.isNotEmpty) ...[
          const SizedBox(height: 10),
          ..._additionalDocs.asMap().entries.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: const Color(0xFF86EFAC), width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file,
                        color: Color(0xFF16A34A), size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.value.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF15803D)),
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _additionalDocs.removeAt(e.key)),
                      child: const Icon(Icons.close,
                          color: AppColors.rejectedText, size: 16),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildFileUploadCard(
      String title,
      String subtitle,
      IconData icon,
      PlatformFile? file,
      VoidCallback onPick,
      VoidCallback onRemove,
      DeviceType device) {
    final pad = device == DeviceType.mobile ? 20.0 : 24.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (file == null)
            InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                height: device == DeviceType.mobile ? 120 : 140,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.03),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.3), width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload_outlined,
                        size: 48, color: AppColors.primary.withOpacity(0.6)),
                    const SizedBox(height: 12),
                    const Text('Click to upload',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                    const SizedBox(height: 4),
                    const Text('PDF, Word, Excel, Images supported',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.approvedBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.approvedBorder, width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.check_circle,
                        color: AppColors.approvedText, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(file.name,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.approvedText),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('${(file.size / 1024).toStringAsFixed(1)} KB',
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    AppColors.approvedText.withOpacity(0.7))),
                      ],
                    ),
                  ),
                  IconButton(
                      onPressed: onRemove,
                      icon: const Icon(Icons.close,
                          color: AppColors.rejectedText, size: 24),
                      tooltip: 'Remove file'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── ACTION BUTTONS ───────────────────────────────────────────────────
  Widget _buildActionButtons(DeviceType device) {
    final isMobile = device == DeviceType.mobile;

    final backBtn = OutlinedButton.icon(
      onPressed: _currentStep == 1 ? null : _handleBack,
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
      label: const Text('Back', style: TextStyle(fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary.withOpacity(0.3), width: 1.5),
        padding:
            EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    final cancelBtn = OutlinedButton(
      onPressed: _navigateToDashboard,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: const BorderSide(color: AppColors.border, width: 1.5),
        padding:
            EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child:
          const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
    );

    final nextBtn = _currentStep < 3
        ? ElevatedButton.icon(
            onPressed: _handleNext,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Next Step',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 20 : 28, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 4,
              shadowColor: AppColors.primary.withOpacity(0.4),
            ),
          )
        : ElevatedButton.icon(
            onPressed: _isUploading ? null : _handleSubmit,
            icon: _isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white)))
                : const Icon(Icons.check_circle_rounded, size: 20),
            label: Text(
                _isUploading
                    ? 'Submitting...'
                    : (_isEditMode
                        ? 'Resubmit for Validation'
                        : 'Submit for Validation'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 20 : 28, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 4,
              shadowColor: AppColors.primary.withOpacity(0.4),
            ),
          );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          nextBtn,
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: backBtn),
              const SizedBox(width: 10),
              Expanded(child: cancelBtn),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        backBtn,
        const SizedBox(width: 12),
        cancelBtn,
        const Spacer(),
        nextBtn,
      ],
    );
  }
}

/// Immutable metadata for a single tab entry.
class _TabMeta {
  final int number;
  final String title;
  const _TabMeta({required this.number, required this.title});
}
