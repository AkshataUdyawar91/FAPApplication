import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/web_camera_helper.dart' if (dart.library.io) '../../../../core/utils/web_camera_stub.dart';

/// Extraction status for UI feedback
enum ExtractionStatus { none, extracting, success, failed }

/// Data class for an invoice (child of campaign)
class InvoiceItemData {
  final String id;
  PlatformFile? file;
  String invoiceNumber;
  String invoiceDate;
  String totalAmount;
  String gstNumber;
  bool isExtracting;
  ExtractionStatus extractionStatus;
  String? extractionError;
  String? existingFileName;

  // Controllers so programmatic updates (extraction) reflect in the UI
  late final TextEditingController invoiceNumberController;
  late final TextEditingController invoiceDateController;
  late final TextEditingController totalAmountController;
  late final TextEditingController gstNumberController;

  InvoiceItemData({
    required this.id,
    this.file,
    this.invoiceNumber = '',
    this.invoiceDate = '',
    this.totalAmount = '',
    this.gstNumber = '',
    this.isExtracting = false,
    this.extractionStatus = ExtractionStatus.none,
    this.extractionError,
    this.existingFileName,
  }) {
    invoiceNumberController = TextEditingController(text: invoiceNumber);
    invoiceDateController = TextEditingController(text: invoiceDate);
    totalAmountController = TextEditingController(text: totalAmount);
    gstNumberController = TextEditingController(text: gstNumber);
  }

  /// Dispose controllers when this invoice is removed
  void dispose() {
    invoiceNumberController.dispose();
    invoiceDateController.dispose();
    totalAmountController.dispose();
    gstNumberController.dispose();
  }
}

/// Data class for a team/campaign
class CampaignItemData {
  final String id;
  String campaignName;   // used as "Dealer Code" in the new UI
  String startDate;
  String endDate;
  String workingDays;
  String dealershipName;
  String dealershipAddress; // used as "City" in the new UI
  PlatformFile? costSummaryFile;
  PlatformFile? activitySummaryFile;
  List<PlatformFile> photos;
  List<InvoiceItemData> invoices;
  String? existingCostSummaryFileName;
  String? existingActivitySummaryFileName;
  List<String>? existingPhotoFileNames;

  CampaignItemData({
    required this.id,
    this.campaignName = '',
    this.startDate = '',
    this.endDate = '',
    this.workingDays = '',
    this.dealershipName = '',
    this.dealershipAddress = '',
    this.costSummaryFile,
    this.activitySummaryFile,
    List<PlatformFile>? photos,
    List<InvoiceItemData>? invoices,
    this.existingCostSummaryFileName,
    this.existingActivitySummaryFileName,
    this.existingPhotoFileNames,
  })  : photos = photos ?? [],
        invoices = invoices ?? [InvoiceItemData(id: '${id}_invoice_1')];

  static const int maxPhotos = 50;
  static const int minPhotos = 3;
}

class CampaignListSection extends StatefulWidget {
  final List<CampaignItemData> campaigns;
  final Function(List<CampaignItemData>) onCampaignsChanged;
  final String? token;
  final String? packageId;
  final String? selectedActivationState;

  const CampaignListSection({
    super.key,
    required this.campaigns,
    required this.onCampaignsChanged,
    this.token,
    this.packageId,
    this.selectedActivationState,
  });

  @override
  State<CampaignListSection> createState() => _CampaignListSectionState();
}

class _CampaignListSectionState extends State<CampaignListSection> {
  late List<CampaignItemData> _campaigns;

  // Controllers keyed by "campaignId_fieldName" so they survive setState rebuilds
  final Map<String, TextEditingController> _controllers = {};

  // Dealer data per campaign
  final Map<String, List<Map<String, dynamic>>> _dealerResults = {};
  final Map<String, bool> _dealerLoading = {};
  final Map<String, bool> _showDealerDropdown = {};
  final Map<String, bool> _dealerSelected = {};
  // Unique dealer names and cities for the selected dealer
  final Map<String, List<String>> _uniqueDealerNames = {};
  final Map<String, List<Map<String, dynamic>>> _cityOptions = {};

  TextEditingController _ctrl(String campaignId, String field, String initialValue) {
    final key = '${campaignId}_$field';
    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController(text: initialValue);
    }
    return _controllers[key]!;
  }

  void _disposeControllersForCampaign(String campaignId) {
    final keys = _controllers.keys.where((k) => k.startsWith('${campaignId}_')).toList();
    for (final k in keys) {
      _controllers.remove(k)?.dispose();
    }
    _dealerResults.remove(campaignId);
    _dealerLoading.remove(campaignId);
    _showDealerDropdown.remove(campaignId);
    _dealerSelected.remove(campaignId);
    _uniqueDealerNames.remove(campaignId);
    _cityOptions.remove(campaignId);
  }

  /// Fetches all dealers from the API filtered by the selected activation state.
  Future<void> _loadDealersForState(String campaignId) async {
    final state = widget.selectedActivationState;
    if (state == null || state.isEmpty || widget.token == null) return;

    setState(() => _dealerLoading[campaignId] = true);
    try {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'));
      final response = await dio.get(
        '/state/dealers',
        queryParameters: {'state': state, 'q': '', 'size': 50},
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );
      if (response.statusCode == 200 && mounted) {
        final data = response.data;
        List<Map<String, dynamic>> dealers;
        if (data is List) {
          dealers = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['items'] != null) {
          dealers = List<Map<String, dynamic>>.from(data['items'] as List);
        } else {
          dealers = [];
        }
        // Extract unique dealer names
        final names = dealers.map((d) => d['dealerName']?.toString() ?? '').toSet().toList()..sort();
        setState(() {
          _dealerResults[campaignId] = dealers;
          _uniqueDealerNames[campaignId] = names;
        });
      }
    } catch (e) {
      debugPrint('Error loading dealers: $e');
    } finally {
      if (mounted) setState(() => _dealerLoading[campaignId] = false);
    }
  }

  /// Called when a dealer NAME is selected — populates city options for that dealer.
  void _onDealerNameSelected(CampaignItemData campaign, String dealerName) {
    final allDealers = _dealerResults[campaign.id] ?? [];
    final matchingDealers = allDealers.where((d) => d['dealerName']?.toString() == dealerName).toList();

    setState(() {
      campaign.dealershipName = dealerName;
      campaign.dealershipAddress = ''; // reset city
      campaign.campaignName = ''; // reset dealer code
      _dealerSelected[campaign.id] = true;
      _cityOptions[campaign.id] = matchingDealers;
    });
    widget.onCampaignsChanged(_campaigns);
  }

  /// Called when a CITY is selected for the chosen dealer — auto-fills dealer code.
  void _onCitySelected(CampaignItemData campaign, Map<String, dynamic> dealer) {
    final dealerCode = dealer['dealerCode']?.toString() ?? '';
    final city = dealer['city']?.toString() ?? '';

    setState(() {
      campaign.dealershipAddress = city;
      campaign.campaignName = dealerCode;
    });
    widget.onCampaignsChanged(_campaigns);
  }

  // ── Test helpers (used by integration_test_runner.dart) ──

  /// Loads dealers from the API for the given campaign, populating internal maps.
  Future<void> testLoadDealers(String campaignId) => _loadDealersForState(campaignId);

  /// Returns the list of unique dealer names loaded for a campaign.
  List<String> testGetDealerNames(String campaignId) => _uniqueDealerNames[campaignId] ?? [];

  /// Programmatically selects a dealer name (same as user picking from dialog).
  void testSelectDealerName(String campaignId, String dealerName) {
    final campaign = _campaigns.firstWhere((c) => c.id == campaignId);
    _onDealerNameSelected(campaign, dealerName);
  }

  /// Returns the city options available after a dealer name is selected.
  List<Map<String, dynamic>> testGetCityOptions(String campaignId) => _cityOptions[campaignId] ?? [];

  /// Programmatically selects a city (same as user picking from dialog).
  void testSelectCity(String campaignId, Map<String, dynamic> dealer) {
    final campaign = _campaigns.firstWhere((c) => c.id == campaignId);
    _onCitySelected(campaign, dealer);
  }

  /// Triggers a UI rebuild.
  // ignore: invalid_use_of_protected_member
  void testRebuild() => setState(() {});

  @override
  void initState() {
    super.initState();
    _campaigns = widget.campaigns.isEmpty
        ? [CampaignItemData(id: 'campaign_1')]
        : widget.campaigns;
    // Sync the default team back to the parent so validation sees it
    if (widget.campaigns.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onCampaignsChanged(_campaigns);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── Mutations ───────────────────────────────────────────────────────

  void _addCampaign() {
    setState(() => _campaigns.add(CampaignItemData(id: 'campaign_${_campaigns.length + 1}')));
    widget.onCampaignsChanged(_campaigns);
  }

  Future<void> _removeCampaign(int index) async {
    if (_campaigns.length <= 1) return;
    final name = _campaigns[index].dealershipName.isNotEmpty
        ? _campaigns[index].dealershipName
        : 'Team ${index + 1}';
    final confirmed = await _confirm('Delete Team', 'Delete "$name"?');
    if (!confirmed || !mounted) return;
    final removed = _campaigns[index];
    setState(() => _campaigns.removeAt(index));
    _disposeControllersForCampaign(removed.id);
    widget.onCampaignsChanged(_campaigns);
  }

  Future<void> _pickPhotos(int campaignIndex) async {
    final campaign = _campaigns[campaignIndex];
    final existing = campaign.existingPhotoFileNames?.length ?? 0;
    final remaining = CampaignItemData.maxPhotos - campaign.photos.length - existing;
    if (remaining <= 0) { _showError('Maximum ${CampaignItemData.maxPhotos} photos reached'); return; }
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
      if (result != null && result.files.isNotEmpty) {
        final toAdd = result.files.take(remaining).toList();
        setState(() => campaign.photos.addAll(toAdd));
        widget.onCampaignsChanged(_campaigns);
      }
    } catch (e) { debugPrint('Error picking photos: $e'); }
  }

  Future<void> _capturePhoto(int campaignIndex) async {
    final campaign = _campaigns[campaignIndex];
    final existing = campaign.existingPhotoFileNames?.length ?? 0;
    final remaining = CampaignItemData.maxPhotos - campaign.photos.length - existing;
    if (remaining <= 0) { _showError('Maximum ${CampaignItemData.maxPhotos} photos reached'); return; }

    if (kIsWeb) {
      // Use web camera dialog with getUserMedia
      final file = await capturePhotoOnWeb(context);
      if (file != null && mounted) {
        setState(() => campaign.photos.add(file));
        widget.onCampaignsChanged(_campaigns);
      }
    } else {
      // Use image_picker for mobile
      try {
        final picker = ImagePicker();
        final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
        if (photo != null) {
          final bytes = await photo.readAsBytes();
          final file = PlatformFile(
            name: photo.name,
            size: bytes.length,
            bytes: bytes,
          );
          setState(() => campaign.photos.add(file));
          widget.onCampaignsChanged(_campaigns);
        }
      } catch (e) { debugPrint('Error capturing photo: $e'); }
    }
  }

  Future<void> _removePhoto(int campaignIndex, int photoIndex) async {
    final confirmed = await _confirm('Delete Photo', 'Delete "${_campaigns[campaignIndex].photos[photoIndex].name}"?');
    if (!confirmed || !mounted) return;
    setState(() => _campaigns[campaignIndex].photos.removeAt(photoIndex));
    widget.onCampaignsChanged(_campaigns);
  }

  void _calculateWorkingDays(CampaignItemData campaign) {
    if (campaign.startDate.isEmpty || campaign.endDate.isEmpty) return;
    try {
      final s = _parseDate(campaign.startDate);
      final e = _parseDate(campaign.endDate);
      if (s == null || e == null) return;
      int days = 0;
      for (var d = s; !d.isAfter(e); d = d.add(const Duration(days: 1))) {
        if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) days++;
      }
      setState(() => campaign.workingDays = days.toString());
      widget.onCampaignsChanged(_campaigns);
    } catch (e) { debugPrint('Error calculating working days: $e'); }
  }

  DateTime? _parseDate(String value) {
    if (value.isEmpty) return null;
    try {
      final p = value.split('-');
      if (p.length == 3) return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
    } catch (_) {}
    return null;
  }

  Future<void> _selectDate(String current, Function(String) onSelected, {DateTime? minDate}) async {
    final first = minDate ?? DateTime(2020);
    DateTime initial = DateTime.now();
    final parsed = _parseDate(current);
    if (parsed != null) initial = parsed;
    if (initial.isBefore(first)) initial = first;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (date != null) onSelected(DateFormat('dd-MM-yyyy').format(date));
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rejectedText, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.rejectedText));

  // ─── Invoice methods ─────────────────────────────────────────────────

  void _addInvoice(int campaignIndex) {
    setState(() {
      final campaign = _campaigns[campaignIndex];
      campaign.invoices.add(InvoiceItemData(
        id: '${campaign.id}_invoice_${campaign.invoices.length + 1}',
      ));
    });
    widget.onCampaignsChanged(_campaigns);
  }

  Future<void> _removeInvoice(int campaignIndex, int invoiceIndex) async {
    if (_campaigns[campaignIndex].invoices.length > 1) {
      final invoice = _campaigns[campaignIndex].invoices[invoiceIndex];
      final label = invoice.invoiceNumber.isNotEmpty ? 'Invoice #${invoice.invoiceNumber}' : 'Invoice ${invoiceIndex + 1}';
      final confirmed = await _confirm('Delete Invoice', 'Are you sure you want to delete "$label"?');
      if (!confirmed || !mounted) return;
      setState(() {
        _campaigns[campaignIndex].invoices.removeAt(invoiceIndex);
      });
      widget.onCampaignsChanged(_campaigns);
    }
  }

  Future<void> _pickInvoiceFile(int campaignIndex, int invoiceIndex) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() => _campaigns[campaignIndex].invoices[invoiceIndex].file = file);
        widget.onCampaignsChanged(_campaigns);
        await _uploadAndExtractInvoice(campaignIndex, invoiceIndex, file);
      }
    } catch (e) {
      debugPrint('Error picking invoice file: $e');
    }
  }

  Future<void> _uploadAndExtractInvoice(int campaignIndex, int invoiceIndex, PlatformFile file) async {
    if (file.bytes == null || widget.token == null) return;

    final invoice = _campaigns[campaignIndex].invoices[invoiceIndex];
    if (mounted) setState(() => invoice.isExtracting = true);

    try {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'));

      final uploadResponse = await dio.post(
        '/documents/upload',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(file.bytes!, filename: file.name),
          'documentType': 'Invoice',
          if (widget.packageId != null) 'packageId': widget.packageId,
        }),
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );

      if (uploadResponse.statusCode == 200) {
        final packageId = uploadResponse.data['packageId']?.toString();
        final documentId = uploadResponse.data['documentId']?.toString();

        if (packageId != null && documentId != null) {
          await _pollForInvoiceExtraction(packageId, documentId, campaignIndex, invoiceIndex);
        }
      }
    } catch (e) {
      debugPrint('Error uploading/extracting invoice: $e');
    } finally {
      if (mounted) {
        setState(() {
          if (campaignIndex < _campaigns.length && invoiceIndex < _campaigns[campaignIndex].invoices.length) {
            _campaigns[campaignIndex].invoices[invoiceIndex].isExtracting = false;
          }
        });
      }
    }
  }

  Future<void> _pollForInvoiceExtraction(String packageId, String documentId, int campaignIndex, int invoiceIndex) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'));
    const maxAttempts = 25;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      try {
        final response = await dio.get(
          '/submissions/$packageId',
          options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
        );

        if (!mounted) return;

        if (response.statusCode == 200 && response.data != null) {
          final documents = response.data['documents'] as List?;
          if (documents != null) {
            final invoiceDoc = documents.firstWhere(
              (doc) => doc['id']?.toString() == documentId,
              orElse: () => null,
            );

            if (invoiceDoc != null && invoiceDoc['extractedData'] != null) {
              var extractedData = invoiceDoc['extractedData'];

              if (extractedData is String && extractedData.isNotEmpty) {
                try {
                  extractedData = jsonDecode(extractedData);
                } catch (_) {}
              }

              if (extractedData is Map) {
                final invNumber = extractedData['InvoiceNumber'] ?? extractedData['invoiceNumber'] ?? '';
                final invDate = extractedData['InvoiceDate'] ?? extractedData['invoiceDate'] ?? '';
                final amount = extractedData['TotalAmount'] ?? extractedData['totalAmount'] ?? '';
                final gst = extractedData['GSTNumber'] ?? extractedData['gstNumber'] ??
                             extractedData['GSTIN'] ?? extractedData['gstin'] ??
                             extractedData['VendorGSTIN'] ?? extractedData['vendorGSTIN'] ??
                             extractedData['SellerGSTIN'] ?? extractedData['sellerGSTIN'] ?? '';

                if (invNumber.toString().isNotEmpty || amount.toString().isNotEmpty) {
                  if (!mounted) return;

                  if (campaignIndex < _campaigns.length && invoiceIndex < _campaigns[campaignIndex].invoices.length) {
                    final invoice = _campaigns[campaignIndex].invoices[invoiceIndex];
                    setState(() {
                      if (invNumber.toString().isNotEmpty) invoice.invoiceNumber = invNumber.toString();
                      if (invDate.toString().isNotEmpty) invoice.invoiceDate = _formatExtractedDate(invDate.toString());
                      if (amount.toString().isNotEmpty) {
                        final amountNum = double.tryParse(amount.toString());
                        if (amountNum != null) {
                          invoice.totalAmount = _formatCurrency(amountNum);
                        } else {
                          invoice.totalAmount = amount.toString();
                        }
                      }
                      if (gst.toString().isNotEmpty) invoice.gstNumber = gst.toString();
                      invoice.isExtracting = false;
                    });
                    widget.onCampaignsChanged(_campaigns);
                    return;
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        if (!mounted) return;
        debugPrint('Invoice polling attempt $attempt failed: $e');
      }
    }
  }

  String _formatExtractedDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      symbol: '₹ ',
      decimalDigits: 2,
      locale: 'en_IN',
    );
    return formatter.format(amount);
  }

  Future<void> _pickCostSummaryFile(int campaignIndex) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'xlsx', 'xls'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _campaigns[campaignIndex].costSummaryFile = result.files.first);
        widget.onCampaignsChanged(_campaigns);
      }
    } catch (e) {
      debugPrint('Error picking cost summary file: $e');
    }
  }

  Future<void> _pickActivitySummaryFile(int campaignIndex) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'xlsx', 'xls'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _campaigns[campaignIndex].activitySummaryFile = result.files.first);
        widget.onCampaignsChanged(_campaigns);
      }
    } catch (e) {
      debugPrint('Error picking activity summary file: $e');
    }
  }

  // ─── BUILD ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final totalPhotos = _campaigns.fold<int>(
        0, (sum, c) => sum + c.photos.length + (c.existingPhotoFileNames?.length ?? 0));
    final totalMax = _campaigns.length * CampaignItemData.maxPhotos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Teams', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                  const SizedBox(height: 2),
                  const Text('Add each team that executed the activation.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    '${_campaigns.length} team${_campaigns.length != 1 ? 's' : ''} added — $totalPhotos / $totalMax photos uploaded',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _addCampaign,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('+ Add Team', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...List.generate(_campaigns.length, (i) => _buildTeamCard(_campaigns[i], i)),
      ],
    );
  }

  Widget _buildTeamCard(CampaignItemData campaign, int index) {
    final photoCount = campaign.photos.length + (campaign.existingPhotoFileNames?.length ?? 0);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Team header
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: Center(child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    campaign.dealershipName.isNotEmpty
                        ? 'Team ${index + 1} — ${campaign.dealershipName}'
                        : 'Team ${index + 1}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                  ),
                ),
                if (campaign.dealershipAddress.isNotEmpty)
                  Text('(${campaign.dealershipAddress})', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                if (_campaigns.length > 1) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _removeCampaign(index),
                    style: TextButton.styleFrom(foregroundColor: AppColors.rejectedText, padding: EdgeInsets.zero),
                    child: const Text('Remove', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // Fields grid
            LayoutBuilder(builder: (ctx, constraints) {
              final narrow = constraints.maxWidth < 500;
              if (narrow) {
                return Column(children: [
                  _dealerNameDropdownField(campaign),
                  const SizedBox(height: 12),
                  _cityDropdownField(campaign),
                  const SizedBox(height: 12),
                  _teamReadonly('Dealer Code', campaign.campaignName.isNotEmpty ? campaign.campaignName : '—'),
                  const SizedBox(height: 12),
                  _teamDateField('Start Date', campaign.startDate, (v) { setState(() { campaign.startDate = v; _calculateWorkingDays(campaign); }); }, required: true),
                  const SizedBox(height: 12),
                  _teamDateField('End Date', campaign.endDate, (v) { setState(() { campaign.endDate = v; _calculateWorkingDays(campaign); }); }, required: true, minDate: _parseDate(campaign.startDate)),
                  const SizedBox(height: 12),
                  _teamReadonly('Working Days', campaign.workingDays.isNotEmpty ? campaign.workingDays : '—'),
                ]);
              }
              return Column(children: [
                Row(children: [
                  Expanded(child: _dealerNameDropdownField(campaign)),
                  const SizedBox(width: 16),
                  Expanded(child: _cityDropdownField(campaign)),
                  const SizedBox(width: 16),
                  Expanded(child: _teamReadonly('Dealer Code', campaign.campaignName.isNotEmpty ? campaign.campaignName : '—')),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _teamDateField('Start Date', campaign.startDate, (v) { setState(() { campaign.startDate = v; _calculateWorkingDays(campaign); }); }, required: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _teamDateField('End Date', campaign.endDate, (v) { setState(() { campaign.endDate = v; _calculateWorkingDays(campaign); }); }, required: true, minDate: _parseDate(campaign.startDate))),
                  const SizedBox(width: 16),
                  Expanded(child: _teamReadonly('Working Days', campaign.workingDays.isNotEmpty ? campaign.workingDays : '—')),
                ]),
              ]);
            }),
            const SizedBox(height: 16),

            // State note
            RichText(text: TextSpan(
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              children: [
                const TextSpan(text: 'State: '),
                TextSpan(text: widget.selectedActivationState ?? 'Not selected', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                const TextSpan(text: '  (all teams share the activation state)'),
              ],
            )),
            const SizedBox(height: 16),

            // Photos
            _buildPhotosSection(campaign, index, photoCount),
          ],
        ),
      ),
    );
  }

  // ─── Dealer name dropdown field ─────────────────────────────────────

  Widget _dealerNameDropdownField(CampaignItemData campaign) {
    final isLoading = _dealerLoading[campaign.id] ?? false;
    final hasState = widget.selectedActivationState != null && widget.selectedActivationState!.isNotEmpty;
    final isSelected = _dealerSelected[campaign.id] == true && campaign.dealershipName.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Dealership Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
          const Text(' *', style: TextStyle(color: Colors.red, fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        InkWell(
          onTap: hasState ? () => _showDealerNamePicker(campaign) : null,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: hasState ? Colors.white : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isSelected ? campaign.dealershipName : (hasState ? 'Select dealer...' : 'Select activation state first'),
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected ? const Color(0xFF111827) : const Color(0xFF9E9E9E),
                    ),
                  ),
                ),
                if (isLoading)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                else if (isSelected)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        campaign.dealershipName = '';
                        campaign.campaignName = '';
                        campaign.dealershipAddress = '';
                        _dealerSelected[campaign.id] = false;
                        _cityOptions[campaign.id] = [];
                      });
                      widget.onCampaignsChanged(_campaigns);
                    },
                    child: const Icon(Icons.close, size: 18, color: Color(0xFF9E9E9E)),
                  )
                else
                  Icon(Icons.arrow_drop_down, size: 22, color: hasState ? AppColors.primary : const Color(0xFF9E9E9E)),
              ],
            ),
          ),
        ),
        if (!hasState)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Please select an activation state in Step 1 first',
                style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
          ),
      ],
    );
  }

  /// Opens a dialog to pick a dealer name (unique names only, no city shown).
  Future<void> _showDealerNamePicker(CampaignItemData campaign) async {
    final state = widget.selectedActivationState;
    if (state == null || state.isEmpty) return;

    // Load dealers if not already loaded
    if (_dealerResults[campaign.id] == null || _dealerResults[campaign.id]!.isEmpty) {
      await _loadDealersForState(campaign.id);
    }
    if (!mounted) return;

    final allNames = List<String>.from(_uniqueDealerNames[campaign.id] ?? []);
    final searchController = TextEditingController();
    List<String> filtered = List.from(allNames);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Select Dealer — $state', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              content: SizedBox(
                width: 400,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search dealer name...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        final q = value.toLowerCase();
                        setDialogState(() {
                          filtered = allNames.where((n) => n.toLowerCase().contains(q)).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.store_outlined, size: 40, color: Colors.grey.withValues(alpha: 0.4)),
                                  const SizedBox(height: 8),
                                  const Text('No dealers found', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                              itemBuilder: (ctx, i) {
                                final name = filtered[i];
                                // Count how many cities this dealer is in
                                final allDealers = _dealerResults[campaign.id] ?? [];
                                final cityCount = allDealers.where((d) => d['dealerName']?.toString() == name).length;
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                  subtitle: Text('$cityCount ${cityCount == 1 ? 'city' : 'cities'}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                                  onTap: () {
                                    _onDealerNameSelected(campaign, name);
                                    Navigator.of(ctx).pop();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              ],
            );
          },
        );
      },
    );
    searchController.dispose();
  }

  // ─── City dropdown field ──────────────────────────────────────────────

  Widget _cityDropdownField(CampaignItemData campaign) {
    final hasDealerSelected = _dealerSelected[campaign.id] == true && campaign.dealershipName.isNotEmpty;
    final hasCitySelected = campaign.dealershipAddress.isNotEmpty;
    final cities = _cityOptions[campaign.id] ?? [];

    // If dealer has only one city, auto-select it
    if (hasDealerSelected && !hasCitySelected && cities.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onCitySelected(campaign, cities.first);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('City', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
          const Text(' *', style: TextStyle(color: Colors.red, fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        InkWell(
          onTap: hasDealerSelected ? () => _showCityPicker(campaign) : null,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: hasDealerSelected ? Colors.white : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasCitySelected ? campaign.dealershipAddress : (hasDealerSelected ? 'Select city...' : 'Select dealer first'),
                    style: TextStyle(
                      fontSize: 14,
                      color: hasCitySelected ? const Color(0xFF111827) : const Color(0xFF9E9E9E),
                    ),
                  ),
                ),
                if (hasCitySelected)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        campaign.dealershipAddress = '';
                        campaign.campaignName = '';
                      });
                      widget.onCampaignsChanged(_campaigns);
                    },
                    child: const Icon(Icons.close, size: 18, color: Color(0xFF9E9E9E)),
                  )
                else
                  Icon(Icons.arrow_drop_down, size: 22, color: hasDealerSelected ? AppColors.primary : const Color(0xFF9E9E9E)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Opens a dialog to pick a city for the selected dealer.
  Future<void> _showCityPicker(CampaignItemData campaign) async {
    final cities = _cityOptions[campaign.id] ?? [];
    if (cities.isEmpty) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Select City — ${campaign.dealershipName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          content: SizedBox(
            width: 350,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: cities.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
              itemBuilder: (ctx, i) {
                final dealer = cities[i];
                final city = dealer['city']?.toString() ?? '';
                final code = dealer['dealerCode']?.toString() ?? '';
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: const Icon(Icons.location_on_outlined, size: 20, color: AppColors.primary),
                  title: Text(city, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  subtitle: Text('Code: $code', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  onTap: () {
                    _onCitySelected(campaign, dealer);
                    Navigator.of(ctx).pop();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ],
        );
      },
    );
  }

  // ─── Field helpers ────────────────────────────────────────────────────

  Widget _teamDateField(String label, String value, Function(String) onChanged, {bool required = false, DateTime? minDate}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
          if (required) const Text(' *', style: TextStyle(color: Colors.red, fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        TextFormField(
          readOnly: true,
          controller: TextEditingController(text: value),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'dd-mm-yyyy',
            hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
            suffixIcon: const Icon(Icons.calendar_today, color: AppColors.primary, size: 18),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            isDense: true,
          ),
          onTap: () => _selectDate(value, onChanged, minDate: minDate),
        ),
      ],
    );
  }

  Widget _teamReadonly(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF374151))),
        ),
      ],
    );
  }

  // ─── Photos section ───────────────────────────────────────────────────

  Widget _buildPhotosSection(CampaignItemData campaign, int campaignIndex, int totalCount) {
    final max = CampaignItemData.maxPhotos;
    final min = CampaignItemData.minPhotos;
    final canAdd = totalCount < max;
    final isBelowMin = totalCount < min;
    final existingNames = campaign.existingPhotoFileNames ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Photos ($totalCount / $max)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isBelowMin ? const Color(0xFFEF4444) : const Color(0xFF374151),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'min $min required',
              style: TextStyle(
                fontSize: 11,
                color: isBelowMin ? const Color(0xFFEF4444) : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        if (isBelowMin) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFEF4444)),
              const SizedBox(width: 4),
              Text(
                'Please upload at least $min photos for this team',
                style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...existingNames.map((name) => _photoTile(name, onRemove: null)),
            ...List.generate(campaign.photos.length, (i) => _photoTile(
              campaign.photos[i].name,
              onRemove: () => _removePhoto(campaignIndex, i),
            )),
            if (canAdd) _addPhotoTile(() => _pickPhotos(campaignIndex)),
            if (canAdd) _capturePhotoTile(() => _capturePhoto(campaignIndex)),
          ],
        ),
      ],
    );
  }

  Widget _photoTile(String name, {required VoidCallback? onRemove}) {
    final display = name.length > 12 ? '${name.substring(0, 12)}...' : name;
    return Container(
      width: 110,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.image, size: 14, color: Color(0xFF16A34A)),
            const Spacer(),
            if (onRemove != null)
              GestureDetector(onTap: onRemove, child: const Icon(Icons.close, size: 14, color: AppColors.rejectedText)),
          ]),
          const SizedBox(height: 4),
          Text(display, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF15803D))),
          const SizedBox(height: 2),
          const Text('Uploaded', style: TextStyle(fontSize: 10, color: Color(0xFF16A34A))),
        ],
      ),
    );
  }

  Widget _addPhotoTile(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate, size: 22, color: AppColors.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 4),
            const Text('+ Upload', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _capturePhotoTile(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt, size: 22, color: AppColors.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 4),
            const Text('+ Capture', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
