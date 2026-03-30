import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../../../../core/constants/api_constants.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/widgets/app_sidebar.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../core/widgets/chat_side_panel.dart';
import '../../../../core/widgets/chat_end_drawer.dart';
import '../../../../core/widgets/nav_item.dart';
import '../../../../core/widgets/photo_thumbnail_gallery.dart';
import '../../../../core/router/app_router.dart';
import '../../../approval/data/models/invoice_summary_data.dart';
import '../../../approval/data/models/campaign_detail_row.dart';
import '../../../approval/presentation/utils/submission_data_transformer.dart';
import '../../../approval/presentation/widgets/invoice_summary_section.dart';
import '../../../approval/presentation/widgets/campaign_details_table.dart';

class AgencySubmissionDetailPage extends ConsumerStatefulWidget {
  final String submissionId;
  final String token;
  final String userName;
  final String poNumber;
  final bool isModal;

  const AgencySubmissionDetailPage({
    super.key,
    required this.submissionId,
    required this.token,
    required this.userName,
    required this.poNumber,
    this.isModal = false,
  });

  @override
  ConsumerState<AgencySubmissionDetailPage> createState() =>
      _AgencySubmissionDetailPageState();
}

class _AgencySubmissionDetailPageState
    extends ConsumerState<AgencySubmissionDetailPage> {
  final _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl))
    ..interceptors.add(PrettyDioLogger());
  // Separate Dio for view/download — no response body logging (base64 floods console)
  final _dioSilent = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl))
    ..interceptors.add(PrettyDioLogger(responseBody: false));

  bool _isLoading = true;
  Map<String, dynamic>? _submission;
  String? _errorMessage;
  bool _isChatOpen = false;
  bool _isSidebarCollapsed = true;

  // Transformed data for ASM-style layout
  InvoiceSummaryData? _invoiceSummary;
  List<CampaignDetailRow> _campaignDetails = [];

  // PO Balance data
  bool _isLoadingBalance = false;
  Map<String, dynamic>? _poBalance;
  String? _balanceError;

  // Submit functionality
  bool _isSubmitting = false;

  // Validation data from submission response
  List<dynamic> _invoiceValidations = [];
  List<dynamic> _photoValidations = [];
  Map<String, dynamic> _costSummaryValidation = {};
  Map<String, dynamic> _activityValidation = {};
  Map<String, dynamic> _enquiryValidation = {};

  // Blob URLs for Cost Summary, Activity Summary, and Enquiry (from campaigns array)
  String? _costSummaryBlobUrl;
  String? _activitySummaryBlobUrl;
  String? _enquiryBlobUrl;

  @override
  void initState() {
    super.initState();
    _debugToken();
    _loadSubmissionDetails();
  }

  void _debugToken() {
    try {
      // Decode JWT token to see its contents
      final parts = widget.token.split('.');
      if (parts.length == 3) {
        // Decode the payload (second part)
        String payload = parts[1];

        // Add padding if needed
        while (payload.length % 4 != 0) {
          payload += '=';
        }

        final decoded = utf8.decode(base64.decode(payload));
        final tokenData = jsonDecode(decoded);
      }
    } catch (e) {
      // Token decode failed silently
    }
  }

  Future<void> _loadSubmissionDetails() async {
    setState(() => _isLoading = true);
    try {
      final response = await _dio.get(
        '/submissions/${widget.submissionId}',
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );
      if (response.statusCode == 200 && mounted) {
        final submissionData = response.data as Map<String, dynamic>;

        // Transform data for ASM-style layout
        final invoiceSummary =
            SubmissionDataTransformer.extractInvoiceSummary(submissionData);
        final campaignDetails =
            SubmissionDataTransformer.transformToCampaignDetails(
                submissionData);

        // Extract validation data from submission response
        final invoiceValidations =
            submissionData['invoiceValidations'] as List<dynamic>? ?? [];
        final photoValidationsRaw =
            submissionData['photoValidations'] as List<dynamic>? ?? [];
        var photoValidations = photoValidationsRaw;
        final costSummaryValidation =
            submissionData['costSummaryValidation'] as Map<String, dynamic>? ??
                {};
        final activityValidation =
            submissionData['activityValidation'] as Map<String, dynamic>? ?? {};
        final enquiryValidation =
            submissionData['enquiryValidation'] as Map<String, dynamic>? ?? {};

        // Fallback: if photoValidations is empty, fetch from validations endpoint
        if (photoValidations.isEmpty) {
          try {
            final valResponse = await _dio.get(
              '/submissions/${widget.submissionId}/validations',
              options: Options(
                  headers: {'Authorization': 'Bearer ${widget.token}'}),
            );
            if (valResponse.statusCode == 200 && valResponse.data != null) {
              final docs = valResponse.data['documents'] as List<dynamic>? ?? [];
              final photoDocs = docs
                  .where((d) => d['documentType'] == 'TeamPhoto')
                  .toList();
              if (photoDocs.isNotEmpty) {
                photoValidations = photoDocs;
              }
            }
          } catch (e2) {
            debugPrint('Fallback photo validation fetch failed: $e2');
          }
        }

        // Extract blob URLs for Cost Summary and Activity Summary from campaigns
        String? costSummaryBlobUrl;
        String? activitySummaryBlobUrl;
        final campaignsList = submissionData['campaigns'] as List<dynamic>? ?? [];
        if (campaignsList.isNotEmpty) {
          final firstCampaign = campaignsList[0] as Map<String, dynamic>;
          costSummaryBlobUrl = firstCampaign['costSummaryBlobUrl']?.toString()
              ?? firstCampaign['costSummaryUrl']?.toString();
          activitySummaryBlobUrl = firstCampaign['activitySummaryBlobUrl']?.toString()
              ?? firstCampaign['activitySummaryUrl']?.toString()
              ?? firstCampaign['activityBlobUrl']?.toString();
        }

        // Extract enquiry blob URL from campaigns
        String? enquiryBlobUrl;
        if (campaignsList.isNotEmpty) {
          final firstCampaign = campaignsList[0] as Map<String, dynamic>;
          enquiryBlobUrl = firstCampaign['enquiryBlobUrl']?.toString()
              ?? firstCampaign['enquiryUrl']?.toString();
        }

        setState(() {
          _submission = submissionData;
          _invoiceSummary = invoiceSummary;
          _campaignDetails = campaignDetails;
          _invoiceValidations = invoiceValidations;
          _photoValidations = photoValidations;
          _costSummaryValidation = costSummaryValidation;
          _activityValidation = activityValidation;
          _enquiryValidation = enquiryValidation;
          _costSummaryBlobUrl = costSummaryBlobUrl;
          _activitySummaryBlobUrl = activitySummaryBlobUrl;
          _enquiryBlobUrl = enquiryBlobUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load submission details';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchPOBalance() async {
    if (widget.poNumber.isEmpty) {
      setState(() {
        _balanceError = 'PO Number not available';
      });
      return;
    }

    setState(() {
      _isLoadingBalance = true;
      _balanceError = null;
      _poBalance = null;
    });

    try {
      final response = await _dio.get(
        '/po-balance/${widget.poNumber}',
        queryParameters: {'companyCode': 'BAL'},
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );

      if (response.statusCode == 200 && mounted) {
        final balanceData = response.data as Map<String, dynamic>;
        setState(() {
          _poBalance = balanceData;
          _isLoadingBalance = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _balanceError = 'Failed to fetch PO balance';
          _isLoadingBalance = false;
        });
      }
    }
  }

  Future<void> _submitSubmission() async {
    // Show confirmation dialog
    final confirmed = await _showSubmitConfirmation();
    if (!confirmed) return;

    setState(() => _isSubmitting = true);

    try {
      final response = await _dio.post(
        '/submissions/${widget.submissionId}/submit',
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Submission submitted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Reload submission details to get updated state
        await _loadSubmissionDetails();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to submit submission';

        // Handle specific error cases
        if (e is DioException) {
          if (e.response?.statusCode == 400) {
            errorMessage =
                e.response?.data?['message'] ?? 'Invalid submission state';
          } else if (e.response?.statusCode == 404) {
            errorMessage = 'Submission not found';
          } else if (e.response?.statusCode == 409) {
            errorMessage = 'Submission already submitted or in wrong state';
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<bool> _showSubmitConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Submit for Review',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Are you sure you want to submit this submission for review? Once submitted, you won\'t be able to edit it unless it\'s rejected.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _formatBalanceDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final utcDate = DateTime.parse(dateStr);
      final localDate = utcDate.toLocal();
      return '${localDate.day}/${localDate.month}/${localDate.year} ${localDate.hour}:${localDate.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  bool _canSubmit(String state) {
    final stateLower = state.toLowerCase();
    // Only allow submit for draft/uploaded — chatbot submissions are already past this stage
    return stateLower == 'draft' || stateLower == 'uploaded';
  }

  String _getCostSummaryFileName() {
    if (_submission == null) return '';
    final campaigns = _submission!['campaigns'] as List? ?? [];
    if (campaigns.isEmpty) return '';
    final firstCampaign = campaigns[0] as Map<String, dynamic>;
    return firstCampaign['costSummaryFileName']?.toString() ??
        'Cost Summary.pdf';
  }

  String _getActivitySummaryFileName() {
    if (_submission == null) return '';
    final campaigns = _submission!['campaigns'] as List? ?? [];
    if (campaigns.isEmpty) return '';
    final firstCampaign = campaigns[0] as Map<String, dynamic>;
    return firstCampaign['activitySummaryFileName']?.toString() ??
        'Activity Summary.pdf';
  }

  String _getEnquiryFileName() {
    return 'Enquiry Data.xlsx';
  }

  /// Gets document ID for Cost Summary — checks documents array with multiple type aliases,
  /// then falls back to campaigns array fields.
  String _getCostSummaryDocumentId() {
    // Try documents array with all known type strings
    for (final alias in ['CostSummary', 'Cost Summary', 'costsummary', 'cost_summary']) {
      final id = _getDocumentIdByType(alias);
      if (id.isNotEmpty) return id;
    }
    // Try campaigns array
    if (_submission != null) {
      final campaigns = _submission!['campaigns'] as List? ?? [];
      for (final c in campaigns) {
        final id = (c as Map<String, dynamic>)['costSummaryDocumentId']?.toString()
            ?? c['costSummaryId']?.toString()
            ?? '';
        if (id.isNotEmpty) return id;
      }
    }
    // Try costSummaryValidation object itself
    return _costSummaryValidation['documentId']?.toString()
        ?? _costSummaryValidation['id']?.toString()
        ?? '';
  }

  /// Gets document ID for Activity Summary — checks documents array with multiple type aliases,
  /// then falls back to campaigns array fields.
  String _getActivitySummaryDocumentId() {
    for (final alias in ['ActivitySummary', 'Activity Summary', 'activitysummary', 'activity_summary', 'Activity']) {
      final id = _getDocumentIdByType(alias);
      if (id.isNotEmpty) return id;
    }
    if (_submission != null) {
      final campaigns = _submission!['campaigns'] as List? ?? [];
      for (final c in campaigns) {
        final id = (c as Map<String, dynamic>)['activitySummaryDocumentId']?.toString()
            ?? c['activitySummaryId']?.toString()
            ?? '';
        if (id.isNotEmpty) return id;
      }
    }
    return _activityValidation['documentId']?.toString()
        ?? _activityValidation['id']?.toString()
        ?? '';
  }

  /// Gets document ID for Enquiry — checks documents array with multiple type aliases,
  /// then falls back to campaigns array fields.
  String _getEnquiryDocumentId() {
    for (final alias in ['Enquiry', 'EnquiryData', 'Enquiry Data', 'enquiry', 'enquiry_data']) {
      final id = _getDocumentIdByType(alias);
      if (id.isNotEmpty) return id;
    }
    if (_submission != null) {
      final campaigns = _submission!['campaigns'] as List? ?? [];
      for (final c in campaigns) {
        final id = (c as Map<String, dynamic>)['enquiryDocumentId']?.toString()
            ?? c['enquiryId']?.toString()
            ?? '';
        if (id.isNotEmpty) return id;
      }
    }
    return _enquiryValidation['documentId']?.toString()
        ?? _enquiryValidation['id']?.toString()
        ?? '';
  }

  /// Checks if a validation entry has any warning rules that did not pass.
  bool _hasWarningRules(Map<String, dynamic> validation) {
    try {
      final detailsJson = validation['validationDetailsJson']?.toString() ?? '';
      if (detailsJson.isEmpty) return false;
      final details = json.decode(detailsJson);
      // Check proactiveRules array for warnings
      final rules = (details is Map ? details['proactiveRules'] : null) as List? ?? [];
      for (final rule in rules) {
        final ruleMap = rule as Map<String, dynamic>;
        if (ruleMap['isWarning'] == true && ruleMap['passed'] != true) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Collects all photos from campaigns and matches validation status.
  /// Sorted: failed first, warning next, pending next, passed last.
  List<PhotoThumbnailItem> _collectPhotosWithValidation() {
    final items = <PhotoThumbnailItem>[];
    final campaigns = _submission?['campaigns'] as List? ?? [];
    final packageId = _submission?['id']?.toString() ?? '';
    final state = _submission?['state']?.toString().toLowerCase() ?? '';

    // If submission is still processing, all photos are pending
    final isProcessing = state == 'draft' || state == 'uploaded' ||
        state == 'extracting' || state == 'validating';

    // Build a lookup: documentId -> validation entry
    final validationByDocId = <String, Map<String, dynamic>>{};
    Map<String, dynamic>? aggregateValidation;
    for (final v in _photoValidations) {
      final vMap = v as Map<String, dynamic>;
      final docId = vMap['documentId']?.toString() ?? '';
      if (docId == packageId) {
        aggregateValidation = vMap;
      } else if (docId.isNotEmpty) {
        validationByDocId[docId] = vMap;
      }
    }

    for (final campaign in campaigns) {
      final photos =
          (campaign as Map<String, dynamic>)['photos'] as List? ?? [];
      for (final photo in photos) {
        final photoMap = photo as Map<String, dynamic>;
        final fileName = photoMap['fileName']?.toString() ?? '';
        final docId = photoMap['id']?.toString() ??
            photoMap['photoId']?.toString() ??
            '';

        final bool hasError;
        final bool hasWarning;
        final bool isPending;

        if (isProcessing) {
          // Still processing — grey border
          isPending = true;
          hasError = false;
          hasWarning = false;
        } else {
          // Try per-photo validation first
          final validation = validationByDocId[docId];
          if (validation != null) {
            isPending = false;
            final allPassed = validation['allPassed'] == true ||
                validation['allValidationsPassed'] == true;
            final failureReason =
                validation['failureReason']?.toString() ?? '';
            hasError = !allPassed || failureReason.isNotEmpty;
            // Check for warnings in validationDetailsJson proactiveRules
            hasWarning = !hasError && _hasWarningRules(validation);
          } else if (aggregateValidation != null) {
            // No per-photo validation — don't inherit aggregate allPassed
            // (it includes cross-document checks like "No. of Days" unrelated to individual photo quality)
            isPending = false;
            hasError = false;
            hasWarning = false;
          } else {
            // No validation data — mark as pending (grey border)
            isPending = true;
            hasError = false;
            hasWarning = false;
          }
        }

        if (docId.isNotEmpty) {
          items.add(PhotoThumbnailItem(
            documentId: docId,
            fileName: fileName,
            hasError: hasError,
            hasWarning: hasWarning,
            isPending: isPending,
          ));
        }
      }
    }

    // Sort: failed first, then warning, then pending, then passed
    items.sort((a, b) {
      int priority(PhotoThumbnailItem item) {
        if (item.hasError) return 0;
        if (item.hasWarning) return 1;
        if (item.isPending) return 2;
        return 3;
      }
      return priority(a).compareTo(priority(b));
    });

    return items;
  }

  /// Builds the photo gallery section as a list of widgets for spread.
  List<Widget> _buildPhotoGallerySection() {
    final galleryPhotos = _collectPhotosWithValidation();
    if (galleryPhotos.isEmpty) return [];
    return [
      const SizedBox(height: 24),
      PhotoThumbnailGallery(
        photos: galleryPhotos,
        token: widget.token,
        onPhotoTap: (docId, fileName) => _viewDocument(docId, fileName),
      ),
    ];
  }

  Widget _buildValidationReportSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user,
                    color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                const Text('Validation Summary', style: AppTextStyles.h3),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Invoice Validations
            if (_invoiceValidations.isNotEmpty) ...[
              _buildInvoiceValidationsSection(_invoiceValidations),
              const SizedBox(height: 24),
            ],

            // Cost Summary Validation
            if (_costSummaryValidation.isNotEmpty) ...[
              _buildSingleValidationCard(
                title: 'Cost Summary Validation',
                fileName: _getCostSummaryFileName(),
                validation: _costSummaryValidation,
                documentId: _getCostSummaryDocumentId(),
                blobUrl: _costSummaryBlobUrl,
              ),
              const SizedBox(height: 24),
            ],

            // Activity Validation
            if (_activityValidation.isNotEmpty) ...[
              _buildSingleValidationCard(
                title: 'Activity Validation',
                fileName: _getActivitySummaryFileName(),
                validation: _activityValidation,
                documentId: _getActivitySummaryDocumentId(),
                blobUrl: _activitySummaryBlobUrl,
              ),
              const SizedBox(height: 24),
            ],

            // Enquiry Validation (view/download only, no table)
            if (_enquiryValidation.isNotEmpty) ...[
              _buildSingleValidationCard(
                title: 'Enquiry Validation',
                fileName: _getEnquiryFileName(),
                validation: _enquiryValidation,
                documentId: _getEnquiryDocumentId(),
                blobUrl: _enquiryBlobUrl,
                hideRowsAndBadge: true,
              ),
              const SizedBox(height: 24),
            ],

            // Photo Validations (at bottom)
            if (_photoValidations.isNotEmpty) ...[
              _buildPhotoValidationsSection(_photoValidations),
              const SizedBox(height: 24),
            ],

            // No validations message
            if (_invoiceValidations.isEmpty &&
                _photoValidations.isEmpty &&
                _costSummaryValidation.isEmpty &&
                _activityValidation.isEmpty &&
                _enquiryValidation.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'No validation data available for this submission',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 80) return const Color(0xFF16A34A);
    if (confidence >= 60) return const Color(0xFFF59E0B);
    return const Color(0xFFDC2626);
  }

  Widget _buildInvoiceValidationsSection(List<dynamic> invoiceValidations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...invoiceValidations.map((invoice) {
          final invoiceData = invoice as Map<String, dynamic>;
          return _buildInvoiceValidationCard(invoiceData);
        }),
      ],
    );
  }

  Widget _buildInvoiceValidationCard(Map<String, dynamic> invoice) {
    final fileName = invoice['fileName'] ?? 'Unknown';
    final validationDetailsJson = invoice['validationDetailsJson'] as String?;
    final docId = invoice['documentId']?.toString() ?? invoice['id']?.toString() ?? _getDocumentIdByType('Invoice');

    List<Map<String, dynamic>> allRows = [];

    if (validationDetailsJson != null && validationDetailsJson.isNotEmpty) {
      try {
        final validationDetails =
            jsonDecode(validationDetailsJson) as Map<String, dynamic>;
        allRows = _extractAllValidationRows(validationDetails);
      } catch (e) {
        debugPrint('Error parsing validation details: $e');
      }
    }

    // Filter to only the 9 invoice rows per spec
    allRows = _filterInvoiceRows(allRows);

    return _buildValidationCardWidget(
      title: 'Invoice Validations',
      fileName: fileName,
      passedCount: allRows.where((r) => r['passed'] == true).length,
      totalCount: allRows.length,
      rows: allRows,
      resolvedDocId: docId,
    );
  }

  Widget _buildPhotoValidationsSection(List<dynamic> photoValidations) {
    // Only show the aggregate validation (documentId == packageId), skip per-photo entries
    final packageId = _submission?['id']?.toString() ?? '';
    final aggregateEntries = photoValidations.where((photo) {
      final photoData = photo as Map<String, dynamic>;
      final docId = photoData['documentId']?.toString() ?? '';
      return docId == packageId || docId.isEmpty;
    }).toList();
    // Fallback: if no aggregate found, show the first entry only
    final entriesToShow = aggregateEntries.isNotEmpty ? aggregateEntries : (photoValidations.isNotEmpty ? [photoValidations.first] : []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...entriesToShow.map((photo) {
          final photoData = photo as Map<String, dynamic>;
          return _buildPhotoValidationCard(photoData);
        }),
      ],
    );
  }

  Widget _buildPhotoValidationCard(Map<String, dynamic> photo) {
    final fileName = photo['fileName'] ?? 'Unknown';
    final validationDetailsJson = photo['validationDetailsJson'] as String?;
    final failureReason = photo['failureReason'] as String?;
    final photoDocId = photo['documentId']?.toString() ?? '';

    // Photo validation is aggregate (documentId = packageId). Use first photo's actual ID instead.
    final packageId = _submission?['id']?.toString() ?? '';
    String resolvedPhotoDocId = (photoDocId.isNotEmpty && photoDocId != packageId) ? photoDocId : '';
    
    // Get first photo's real ID from campaigns for View/Download (blob URLs are private Azure storage)
    if (resolvedPhotoDocId.isEmpty) {
      final campaigns = _submission?['campaigns'] as List? ?? [];
      for (final campaign in campaigns) {
        final photos = (campaign as Map<String, dynamic>)['photos'] as List? ?? [];
        if (photos.isNotEmpty) {
          resolvedPhotoDocId = (photos[0] as Map<String, dynamic>)['id']?.toString() ?? '';
          break;
        }
      }
    }

    List<Map<String, dynamic>> allRows = [];

    if (validationDetailsJson != null && validationDetailsJson.isNotEmpty && validationDetailsJson != '{}') {
      try {
        final validationDetails =
            jsonDecode(validationDetailsJson) as Map<String, dynamic>;
        allRows = _extractPhotoValidationRows(validationDetails);
      } catch (e) {
        debugPrint('Error parsing validation details: $e');
      }
    }

    // Fallback: if no rows extracted, parse failureReason
    if (allRows.isEmpty && failureReason != null && failureReason.isNotEmpty) {
      final reasons = failureReason.split('; ');
      for (final reason in reasons) {
        allRows.add({'label': reason.trim(), 'passed': false, 'message': reason.trim()});
      }
    }

    return _buildValidationCardWidget(
      title: 'Photo Validations',
      fileName: fileName,
      passedCount: 0,
      totalCount: 0,
      rows: allRows,
    );
  }

  /// Extracts photo-specific validation rows with descriptive labels and natural language messages.
  List<Map<String, dynamic>> _extractPhotoValidationRows(Map<String, dynamic> details) {
    final rows = <Map<String, dynamic>>[];

    void addRow(String label, bool passed, String message) {
      rows.add({'label': label, 'passed': passed, 'message': message});
    }

    final fieldPresence = details['fieldPresence'] as Map<String, dynamic>?;
    final crossDocument = details['crossDocument'] as Map<String, dynamic>?;
    final totalPhotos = fieldPresence?['totalPhotos'];

    // Photo Count
    if (totalPhotos != null && totalPhotos > 0) {
      addRow('Photo count', true, '$totalPhotos Photos uploaded');

      final photosWithDate = fieldPresence?['photosWithDate'] ?? 0;
      addRow('Date on photos', photosWithDate == totalPhotos,
          '$photosWithDate/$totalPhotos Photos have date mentioned');

      final photosWithLocation = fieldPresence?['photosWithLocation'] ?? 0;
      addRow('GPS coordinates', photosWithLocation == totalPhotos,
          '$photosWithLocation/$totalPhotos Photos have coordinates present');
    }

    // No. of Days — uses unique photo dates vs activity summary days
    if (crossDocument != null) {
      final daysMatch = crossDocument['numberOfDaysMatches'] ?? crossDocument['photoCountMatchesManDays'];
      if (daysMatch != null) {
        final uniquePhotoDays = crossDocument['uniquePhotoDays'] ?? crossDocument['photoCount'] ?? totalPhotos ?? 0;
        final activityDays = crossDocument['activitySummaryDays'] ?? crossDocument['costSummaryDays'] ?? 0;
        addRow('No. of days', daysMatch == true,
            daysMatch == true
                ? 'Photo days ($uniquePhotoDays) matches Activity Summary days ($activityDays)'
                : 'Photo days ($uniquePhotoDays) does not match Activity Summary days ($activityDays)');
      }
    }

    // Blue T-shirt & Branded 3W
    if (totalPhotos != null && totalPhotos > 0) {
      final photosWithBlueTshirt = fieldPresence?['photosWithBlueTshirt'] ?? 0;
      addRow('Promoter wearning blue T-shirt', photosWithBlueTshirt == totalPhotos,
          '$photosWithBlueTshirt/$totalPhotos Photos have promoters wearing blue T-shirt');

      final photosWithVehicle = fieldPresence?['photosWithVehicle'] ?? 0;
      addRow('Branded 3 wheeler', photosWithVehicle == totalPhotos,
          '$photosWithVehicle/$totalPhotos Photos have branded 3 wheelers');
    }

    return rows;
  }

  /// Converts a rule code to a readable label.
  String _ruleCodeToLabel(String ruleCode) {
    const labelMap = {
      // Chatbot rule codes
      'INV_INVOICE_NUMBER_PRESENT': 'Invoice Number',
      'INV_DATE_PRESENT': 'Invoice Date',
      'INV_AMOUNT_PRESENT': 'Invoice amount',
      'INV_GST_NUMBER_PRESENT': 'GSTIN for State',
      'INV_GST_PERCENT_PRESENT': 'GST %',
      'INV_HSN_SAC_PRESENT': 'HSN/SAC Code',
      'INV_VENDOR_CODE_PRESENT': 'Agency Code',
      'INV_AGENCY_NAME_ADDRESS': 'Agency Name & Addresses',
      'INV_BILLING_NAME_ADDRESS': 'Billing Name & Address',
      'INV_SUPPLIER_STATE': 'Supplier State',
      'INV_PO_NUMBER_MATCH': 'PO Number',
      'INV_AMOUNT_VS_PO_BALANCE': 'Invoice amount limit',
      // Web workflow rule codes
      'INV_NUMBER_PRESENT': 'Invoice Number',
      'INV_GST_PRESENT': 'GSTIN for State',
      'INV_PO_MATCH': 'PO Number',
      // PO rule codes
      'PO_SAP_VERIFIED': 'SAP Verification',
      'PO_DATE_VALID': 'Date Validation',
      // Activity Summary rule codes
      'AS_DEALER_LOCATION_PRESENT': 'Dealer/Location',
      'AS_TOTAL_DAYS': 'Total No. of Days',
      'AS_TOTAL_WORKING_DAYS': 'Total No. of Working Days',
      'AS_DAYS_MATCH_COST_SUMMARY': 'Days worked matches Cost Summary',
      'AS_DAYS_MATCH_TEAM_DETAILS': 'Days Match (Team Details)',
      // Cost Summary rule codes
      'CS_PLACE_OF_SUPPLY': 'Place of Supply',
      'CS_PLACE_OF_SUPPLY_PRESENT': 'Place of Supply',
      'CS_NUMBER_OF_DAYS': 'No. of Days',
      'CS_NUMBER_OF_ACTIVATIONS': 'No. of Activations',
      'CS_NUMBER_OF_TEAMS': 'No. of Teams',
      'CS_ELEMENT_WISE_COST': 'Element-wise Cost',
      'CS_ELEMENT_WISE_QTY': 'Element-wise Quantity',
      'CS_FIXED_COST_LIMITS': 'Fixed Cost Limits',
      'CS_VARIABLE_COST_LIMITS': 'Variable Cost Limits',
      'CS_TOTAL_DAYS_PRESENT': 'Total Days',
      'CS_TOTAL_VS_INVOICE': 'Total vs Invoice',
      'CS_ELEMENT_COST_VS_RATES': 'Element Cost vs Rates',
      // Enquiry rule codes
      'EQ_STATE': 'State',
      'EQ_DATE': 'Date',
      'EQ_DEALER_CODE': 'Dealer Code',
      'EQ_DEALER_NAME': 'Dealer Name',
      'EQ_DISTRICT': 'District',
      'EQ_PINCODE': 'Pincode',
      'EQ_CUSTOMER_NAME': 'Customer Name',
      'EQ_CUSTOMER_PHONE': 'Customer Phone',
      'EQ_TEST_RIDE': 'Test Ride',
      // Photo rule codes
      'PHOTO_COUNT': 'Photo Count',
      'PHOTO_DATE_VISIBLE': 'Date on Photos',
      'PHOTO_GPS_VISIBLE': 'GPS Coordinates',
      'PHOTO_BLUE_TSHIRT': 'Promoter wearning Blue T-shirt',
      'PHOTO_3W_VEHICLE': 'Branded 3 wheeler',
    };
    return labelMap[ruleCode] ??
        ruleCode
            .replaceAll('_', ' ')
            .replaceFirst(RegExp(r'^(INV|AS|CS|PO|EQ|PHOTO)\s'), '')
            .trim();
  }

  Widget _buildSingleValidationCard({
    required String title,
    String? fileName,
    required Map<String, dynamic> validation,
    String? documentId,
    String? blobUrl,
    bool hideRowsAndBadge = false,
  }) {
    final resolvedDocId = (documentId != null && documentId.isNotEmpty)
        ? documentId
        : validation['documentId']?.toString() ?? validation['id']?.toString() ?? '';
    final resolvedBlobUrl = blobUrl ?? '';

    final validationDetailsJson =
        validation['validationDetailsJson'] as String?;

    List<Map<String, dynamic>> allRows = [];

    if (!hideRowsAndBadge && validationDetailsJson != null && validationDetailsJson.isNotEmpty) {
      try {
        final validationDetails =
            jsonDecode(validationDetailsJson) as Map<String, dynamic>;
        allRows = _extractAllValidationRows(validationDetails);
      } catch (e) {
        debugPrint('Error parsing validation details for $title: $e');
      }
    }

    // For Cost Summary, show only the 8 key validation rows
    if (!hideRowsAndBadge && title.toLowerCase().contains('cost summary')) {
      allRows = _filterCostSummaryRows(allRows);
    }

    // For Activity, show only the 1 key validation row
    if (!hideRowsAndBadge && title.toLowerCase().contains('activity')) {
      allRows = _filterActivityRows(allRows);
    }

    final passedCount = hideRowsAndBadge ? 0 : allRows.where((r) => r['passed'] == true).length;
    final totalCount = hideRowsAndBadge ? 0 : allRows.length;

    return _buildValidationCardWidget(
      title: title,
      fileName: fileName ?? '',
      passedCount: passedCount,
      totalCount: totalCount,
      rows: hideRowsAndBadge ? [] : allRows,
      resolvedDocId: resolvedDocId,
      resolvedBlobUrl: resolvedBlobUrl,
    );
  }

  /// Finds the first source row matching any of the given aliases (case-insensitive).
  Map<String, dynamic>? _findRow(List<Map<String, dynamic>> rows, List<String> aliases) {
    for (final row in rows) {
      final label = (row['label'] as String? ?? '').toLowerCase();
      if (aliases.contains(label)) return row;
    }
    return null;
  }

  /// Filters invoice rows to exactly 9 rows in Excel order. Skips rows not found.
  List<Map<String, dynamic>> _filterInvoiceRows(List<Map<String, dynamic>> rows) {
    const orderedSpec = [
      ('Invoice number', ['invoice number']),
      ('Invoice date', ['invoice date']),
      ('Invoice amount', ['invoice amount']),
      ('Agency name & addresses', ['agency name & addresses', 'agency name & address']),
      ('Agency code', ['agency code', 'agency code match', 'vendor code']),
      ('PO number', ['po number', 'po number match']),
      ('GSTIN for state', ['gstin for state', 'gst number', 'gst state match']),
      ('GST %', ['gst %', 'gst percentage']),
      ('Invoice amount limit', ['invoice amount limit', 'amount vs po balance']),
    ];
    final result = <Map<String, dynamic>>[];
    for (final (displayLabel, aliases) in orderedSpec) {
      final match = _findRow(rows, aliases);
      if (match != null) {
        result.add({'label': displayLabel, 'passed': match['passed'], 'message': match['message']});
      }
    }
    return result;
  }

  /// Filters cost summary rows to exactly 8 rows in Excel order. Skips rows not found.
  List<Map<String, dynamic>> _filterCostSummaryRows(List<Map<String, dynamic>> rows) {
    const orderedSpec = [
      ('State/Place of supply', ['place of supply', 'state/place of supply']),
      ('Element wise cost', ['element-wise cost', 'element wise cost']),
      ('No of days', ['no. of days', 'no of days']),
      ('Element wise quantity', ['element-wise quantity', 'element wise quantity']),
      ('Total cost', ['total cost validation', 'total cost']),
      ('Element cost limit as per state rate', ['element costs validation', 'element cost vs rates']),
      ('Fixed cost limit as per state rate', ['fixed costs validation']),
      ('Variable cost limit as per state rate', ['variable costs validation']),
    ];
    final result = <Map<String, dynamic>>[];
    for (final (displayLabel, aliases) in orderedSpec) {
      final match = _findRow(rows, aliases);
      if (match != null) {
        result.add({'label': displayLabel, 'passed': match['passed'], 'message': match['message']});
      }
    }
    return result;
  }

  /// Filters activity rows to exactly 1 row. Skips if not found.
  List<Map<String, dynamic>> _filterActivityRows(List<Map<String, dynamic>> rows) {
    const orderedSpec = [
      ('Days worked matches cost summary', ['days worked matches cost summary', 'days match (cost summary)', 'number of days match']),
    ];
    final result = <Map<String, dynamic>>[];
    for (final (displayLabel, aliases) in orderedSpec) {
      final match = _findRow(rows, aliases);
      if (match != null) {
        result.add({'label': displayLabel, 'passed': match['passed'], 'message': match['message']});
      }
    }
    return result;
  }

  /// Extracts all validation rows from ValidationDetailsJson.
  /// Reads: proactiveRules, fieldPresence, crossDocument, amountConsistency,
  /// lineItemMatching, vendorMatching, completeness — deduplicating by label.
  List<Map<String, dynamic>> _extractAllValidationRows(
      Map<String, dynamic> details) {
    final rows = <Map<String, dynamic>>[];
    final seenLabels = <String>{};

    void addRow(String label, bool passed, String message) {
      final key = label.toLowerCase();
      if (seenLabels.contains(key)) return;
      seenLabels.add(key);
      rows.add({'label': label, 'passed': passed, 'message': message});
    }

    // 1. Proactive rules (richest detail — add first so they win dedup)
    final proactiveRules = (details['proactiveRules'] as List<dynamic>?) ??
        (details['rules'] as List<dynamic>?);
    if (proactiveRules != null) {
      for (final rule in proactiveRules) {
        if (rule is! Map<String, dynamic>) continue;
        final ruleCode = (rule['RuleCode'] ?? rule['ruleCode'] ?? '') as String;
        final passed = (rule['Passed'] ?? rule['passed'] ?? false) as bool;
        final extracted = rule['ExtractedValue'] ?? rule['extractedValue'];
        final expected = rule['ExpectedValue'] ?? rule['expectedValue'];

        final label = _ruleCodeToLabel(ruleCode);
        String message;
        if (passed) {
          message = extracted != null ? extracted.toString() : 'Passed';
        } else {
          if (extracted != null && expected != null) {
            message = 'Found: $extracted, Expected: $expected';
          } else {
            message = 'Field is missing';
          }
        }
        addRow(label, passed, message);
      }
    }

    // 2. Field presence — missing fields
    final fieldPresence = details['fieldPresence'] as Map<String, dynamic>?;
    if (fieldPresence != null) {
      final missingFields =
          fieldPresence['missingFields'] as List<dynamic>? ?? [];
      final totalRecords = fieldPresence['totalRecords'];

      if (totalRecords == null) {
        for (final field in missingFields) {
          addRow(field.toString(), false, 'Field is missing');
        }
        // Photo-specific counters
        final totalPhotos = fieldPresence['totalPhotos'];
        if (totalPhotos != null) {
          final photosWithDate = fieldPresence['photosWithDate'] ?? 0;
          final photosWithLocation = fieldPresence['photosWithLocation'] ?? 0;
          final photosWithBlueTshirt =
              fieldPresence['photosWithBlueTshirt'] ?? 0;
          final photosWithVehicle = fieldPresence['photosWithVehicle'] ?? 0;
          final photosWithFace = fieldPresence['photosWithFace'] ?? 0;

          addRow('Date in Photos', photosWithDate == totalPhotos,
              'Present in ${(photosWithDate * 100 / totalPhotos).toStringAsFixed(1)}% photos');
          addRow('Location in Photos', photosWithLocation == totalPhotos,
              'Present in ${(photosWithLocation * 100 / totalPhotos).toStringAsFixed(1)}% photos');
          addRow('Blue T-shirt Detection', photosWithBlueTshirt > 0,
              'Detected in ${(photosWithBlueTshirt * 100 / totalPhotos).toStringAsFixed(1)}% photos');
          addRow('Bajaj Vehicle Detection', photosWithVehicle > 0,
              'Detected in ${(photosWithVehicle * 100 / totalPhotos).toStringAsFixed(1)}% photos');
          addRow('Face Detection', photosWithFace > 0,
              'Detected in ${(photosWithFace * 100 / totalPhotos).toStringAsFixed(1)}% photos');
        }
      } else {
        // Enquiry: per-field record counts
        final fieldMap = {
          'recordsWithState': 'State',
          'recordsWithDate': 'Date',
          'recordsWithDealerCode': 'Dealer Code',
          'recordsWithDealerName': 'Dealer Name',
          'recordsWithDistrict': 'District',
          'recordsWithPincode': 'Pincode',
          'recordsWithCustomerName': 'Customer Name',
          'recordsWithCustomerNumber': 'Customer Number',
          'recordsWithTestRide': 'Test Ride',
        };
        for (final entry in fieldMap.entries) {
          final count = fieldPresence[entry.key];
          if (count != null) {
            addRow(entry.value, count == totalRecords,
                'Present in $count/$totalRecords records');
          }
        }
      }
    }

    // 3. Cross-document checks
    final crossDocument = details['crossDocument'] as Map<String, dynamic>?;
    if (crossDocument != null) {
      final checkMap = {
        'totalCostValid': ('Total Cost Validation', 'Total cost matches invoice', 'Total cost does not match invoice'),
        'elementCostsValid': ('Element Costs Validation', 'Element costs are valid', 'Element costs are invalid'),
        'fixedCostsValid': ('Fixed Costs Validation', 'Fixed costs are valid', 'Fixed costs are invalid'),
        'variableCostsValid': ('Variable Costs Validation', 'Variable costs are valid', 'Variable costs are invalid'),
        'numberOfDaysMatches': ('Number of Days Match', 'Days match between documents', 'Days mismatch between documents'),
        'photoCountMatchesManDays': ('Photo Count vs Man Days', 'Photo count matches man days', 'Photo count does not match man days'),
        'manDaysWithinCostSummaryDays': ('Man Days vs Cost Summary Days', 'Man days within cost summary days', 'Man days exceed cost summary days'),
        'agencyCodeMatches': ('Agency Code Match', 'Agency code matches', 'Agency code mismatch'),
        'poNumberMatches': ('PO Number Match', 'PO number matches', 'PO number mismatch'),
        'gstStateMatches': ('GST State Match', 'GST state matches', 'GST state mismatch'),
        'hsnSacCodeValid': ('HSN/SAC Code', 'HSN/SAC code is valid', 'HSN/SAC code is invalid'),
        'invoiceAmountValid': ('Invoice Amount', 'Invoice amount is valid', 'Invoice amount is invalid'),
        // poBalanceValid intentionally excluded — use INV_AMOUNT_VS_PO_BALANCE from proactiveRules instead
        // to avoid showing a default "Pass" when the balance was never actually checked.
        'gstPercentageValid': ('GST Percentage', 'GST percentage is valid', 'GST percentage is invalid'),
      };
      for (final entry in checkMap.entries) {
        final val = crossDocument[entry.key];
        if (val != null && val is bool) {
          addRow(entry.value.$1, val, val ? entry.value.$2 : entry.value.$3);
        }
      }
      final issues = crossDocument['issues'] as List<dynamic>? ?? [];
      for (final issue in issues) {
        addRow(issue.toString(), false, issue.toString());
      }
    }

    // 4. Amount consistency
    final amountConsistency =
        details['amountConsistency'] as Map<String, dynamic>?;
    if (amountConsistency != null) {
      final isConsistent = amountConsistency['isConsistent'] ?? false;
      final invoiceTotal = amountConsistency['invoiceTotal'];
      final costTotal = amountConsistency['costSummaryTotal'];
      final pctDiff = amountConsistency['percentageDifference'];
      addRow(
        'Amount Consistency',
        isConsistent == true,
        isConsistent == true
            ? 'Invoice and Cost Summary amounts match'
            : 'Invoice: $invoiceTotal vs Cost Summary: $costTotal (${pctDiff}% diff)',
      );
    }

    // 5. Line item matching
    final lineItemMatching =
        details['lineItemMatching'] as Map<String, dynamic>?;
    if (lineItemMatching != null) {
      final allMatched = lineItemMatching['allItemsMatched'] ?? false;
      final missing = lineItemMatching['missingItemCodes'] as List<dynamic>? ?? [];
      addRow(
        'Line Item Matching',
        allMatched == true,
        allMatched == true
            ? 'All PO line items found in invoice'
            : 'Missing ${missing.length} items: ${missing.join(", ")}',
      );
    }

    // 6. Vendor matching
    final vendorMatching =
        details['vendorMatching'] as Map<String, dynamic>?;
    if (vendorMatching != null) {
      final isMatched = vendorMatching['isMatched'] ?? false;
      final poVendor = vendorMatching['poVendor'] ?? 'N/A';
      final invVendor = vendorMatching['invoiceVendor'] ?? 'N/A';
      addRow(
        'Vendor Matching',
        isMatched == true,
        isMatched == true
            ? 'Vendor information matches across documents'
            : 'PO: $poVendor vs Invoice: $invVendor',
      );
    }

    // 7. Completeness
    final completeness = details['completeness'] as Map<String, dynamic>?;
    if (completeness != null) {
      final isComplete = completeness['isComplete'] ?? false;
      final missingItems = completeness['missingItems'] as List<dynamic>? ?? [];
      addRow(
        'Package Completeness',
        isComplete == true,
        isComplete == true
            ? 'All required documents present'
            : 'Missing: ${missingItems.join(", ")}',
      );
    }

    return rows;
  }

  /// Reusable validation card with header and table rows.
  Widget _buildValidationCardWidget({
    required String title,
    required String fileName,
    required int passedCount,
    required int totalCount,
    required List<Map<String, dynamic>> rows,
    String resolvedDocId = '',
    String resolvedBlobUrl = '',
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 240, 237, 237),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: AppTextStyles.bodyMedium
                              .copyWith(fontWeight: FontWeight.w600)),
                      if (fileName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(fileName,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textSecondary)),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (totalCount > 0)
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${totalCount > 0 ? (passedCount * 100 ~/ totalCount) : 0}% ',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                            TextSpan(
                              text: 'Passed',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: const Color(0xFF16A34A),
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (resolvedDocId.isNotEmpty || resolvedBlobUrl.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 28,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (resolvedDocId.isNotEmpty) {
                              _viewDocument(resolvedDocId, fileName ?? title);
                            } else {
                              _openBlobUrl(resolvedBlobUrl, fileName ?? title);
                            }
                          },
                          icon: const Icon(Icons.visibility, size: 13),
                          label: const Text('View', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 28,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (resolvedDocId.isNotEmpty) {
                              _downloadDocumentDirect(resolvedDocId, fileName ?? title);
                            } else {
                              _downloadByBlobUrl(resolvedBlobUrl, fileName ?? title);
                            }
                          },
                          icon: const Icon(Icons.download, size: 13),
                          label: const Text('Download', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (rows.isNotEmpty) _buildValidationRowsTable(rows),
        ],
      ),
    );
  }

  /// Renders a table of validation rows with WHAT WAS CHECKED / RESULT / WHAT WAS FOUND columns.
  Widget _buildValidationRowsTable(List<Map<String, dynamic>> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text('What was checked',
                    style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontSize: 11)),
              ),
              SizedBox(
                width: 80,
                child: Text('Result',
                    style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontSize: 11),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Text('What was found',
                    style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontSize: 11)),
              ),
            ],
          ),
        ),
        ...rows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          final isLast = index == rows.length - 1;
          final label = row['label'] ?? 'Unknown';
          final passed = row['passed'] ?? false;
          final message = row['message'] ?? '';
          final statusColor =
              passed ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                left: const BorderSide(color: Color(0xFFE5E7EB)),
                right: const BorderSide(color: Color(0xFFE5E7EB)),
                bottom: BorderSide(
                    color: const Color(0xFFE5E7EB),
                    width: isLast ? 1 : 0.5),
              ),
              borderRadius: isLast
                  ? const BorderRadius.vertical(bottom: Radius.circular(8))
                  : BorderRadius.zero,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Text(label,
                      style: AppTextStyles.bodySmall
                          .copyWith(fontWeight: FontWeight.w500)),
                ),
                SizedBox(
                  width: 80,
                  child: Text(passed ? 'Pass' : 'Fail',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 11),
                      textAlign: TextAlign.center),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Text(message,
                      style: AppTextStyles.bodySmall.copyWith(
                          color: passed
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                          fontStyle:
                              passed ? FontStyle.normal : FontStyle.italic)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildValidationSection(String title, List<dynamic> validations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'What was checked',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  'Result',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Text(
                  'What was found',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Table Rows
        ...validations.asMap().entries.map((entry) {
          final index = entry.key;
          final validation = entry.value as Map<String, dynamic>;
          final isLast = index == validations.length - 1;

          final field = validation['field'] ?? validation['item'] ?? 'Unknown';
          final passed = validation['passed'] ?? false;
          final value = validation['value'];
          final message = validation['message'];
          final label = validation['label'];

          final statusColor =
              passed ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                left: BorderSide(color: const Color(0xFFE5E7EB)),
                right: BorderSide(color: const Color(0xFFE5E7EB)),
                bottom: BorderSide(
                  color: const Color(0xFFE5E7EB),
                  width: isLast ? 1 : 0.5,
                ),
              ),
              borderRadius: isLast
                  ? const BorderRadius.vertical(bottom: Radius.circular(8))
                  : BorderRadius.zero,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Column 1: What was checked
                Expanded(
                  flex: 3,
                  child: Text(
                    label ?? field,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Column 2: Status
                SizedBox(
                  width: 80,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        passed ? Icons.check_circle : Icons.cancel,
                        color: statusColor,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        passed ? 'Pass' : 'Fail',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Column 3: What was found
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (value != null)
                        Text(
                          value.toString(),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      if (message != null)
                        Text(
                          message.toString(),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: const Color(0xFFDC2626),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      if (value == null && message == null)
                        Text(
                          '-',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRequiredItemsSection(List<dynamic> requiredItems) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Required Items in Photo',
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'What was checked',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  'Result',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Text(
                  'What was found',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Table Rows
        ...requiredItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value as Map<String, dynamic>;
          final isLast = index == requiredItems.length - 1;

          final itemName = item['item'] ?? 'Unknown';
          final present = item['present'] ?? false;
          final confidence = item['confidence'];

          final statusColor =
              present ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                left: BorderSide(color: const Color(0xFFE5E7EB)),
                right: BorderSide(color: const Color(0xFFE5E7EB)),
                bottom: BorderSide(
                  color: const Color(0xFFE5E7EB),
                  width: isLast ? 1 : 0.5,
                ),
              ),
              borderRadius: isLast
                  ? const BorderRadius.vertical(bottom: Radius.circular(8))
                  : BorderRadius.zero,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Column 1: What was checked
                Expanded(
                  flex: 3,
                  child: Text(
                    itemName,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Column 2: Status
                SizedBox(
                  width: 80,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        present ? Icons.check_circle : Icons.cancel,
                        color: statusColor,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        present ? 'Pass' : 'Fail',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Column 3: What was found (confidence score)
                Expanded(
                  flex: 3,
                  child: confidence != null
                      ? Row(
                          children: [
                            Text(
                              present ? 'Detected with ' : 'Not detected, ',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getConfidenceColor(
                                        (confidence as num).toDouble() * 100)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _getConfidenceColor(
                                      (confidence as num).toDouble() * 100),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                '${((confidence as num) * 100).toStringAsFixed(0)}% confidence',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: _getConfidenceColor(
                                      (confidence as num).toDouble() * 100),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Text(
                          present ? 'Detected' : 'Not detected',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _navigateToUpload() {
    context.pushNamed('agency-upload', extra: {
      'token': widget.token,
      'userName': widget.userName,
    });
  }

  List<NavItem> _getNavItems(BuildContext context) {
    return [
      NavItem(
          icon: Icons.smart_toy,
          label: 'Assistant',
          onTap: () => context.go('/home?view=chatbot')),
      NavItem(
          icon: Icons.list_alt,
          label: 'My Requests',
          isActive: true,
          onTap: () => context.go('/home?view=requests')),
      NavItem(
          icon: Icons.add,
          label: 'New Claim',
          onTap: _navigateToUpload),
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final device = getDeviceType(width);
        final isMobile = device == DeviceType.mobile;

        return Scaffold(
          appBar: widget.isModal
              ? AppBar(
                  backgroundColor: const Color(0xFF003087),
                  title: const Text('Submission Details',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                  ],
                )
              : isMobile
                  ? AppBar(
                      backgroundColor: const Color(0xFF1E3A8A),
                      title: const Text('Bajaj',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      iconTheme: const IconThemeData(color: Colors.white),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Back to Dashboard',
                        ),
                      ],
                    )
                  : null,
          drawer: (!widget.isModal && isMobile)
              ? AppDrawer(
                  userName: widget.userName,
                  userRole: 'Agency',
                  navItems: _getNavItems(context),
                  onLogout: () => handleLogout(context, ref),
                )
              : null,
          body: Column(
            children: [
              if (!widget.isModal && !isMobile) _buildTopBar(),
              Expanded(
                child: Row(
                  children: [
                    if (!widget.isModal && !isMobile)
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
                          if (!isMobile) _buildDesktopHeader(device),
                          Expanded(
                            child: _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : _errorMessage != null
                                    ? _buildError()
                                    : _buildContent(device),
                          ),
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
          endDrawer: (!widget.isModal && isMobile)
              ? ChatEndDrawer(token: widget.token, userName: widget.userName)
              : null,
          floatingActionButton: (widget.isModal || (_isChatOpen && !isMobile))
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

  Widget _buildDesktopHeader(DeviceType device) {
    final fapNumber = _submission?['submissionNumber']?.toString() ??
        'FAP-${widget.submissionId.length >= 8 ? widget.submissionId.substring(0, 8).toUpperCase() : widget.submissionId.toUpperCase()}';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: device == DeviceType.desktop ? 24 : 16,
        vertical: 16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (!widget.isModal) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Back to Dashboard',
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Submission Details', style: AppTextStyles.h2),
                const SizedBox(height: 4),
                Text(fapNumber, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'An error occurred',
                style: AppTextStyles.h3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(DeviceType device) {
    if (_submission == null) return const SizedBox();

    final state = _submission!['state']?.toString() ?? 'Unknown';
    final fapNumber = _submission!['submissionNumber']?.toString() ??
        'FAP-${widget.submissionId.length >= 8 ? widget.submissionId.substring(0, 8).toUpperCase() : widget.submissionId.toUpperCase()}';
    final hPad = responsiveValue<double>(MediaQuery.of(context).size.width,
        mobile: 12, tablet: 16, desktop: 24);
    final isMobile = device == DeviceType.mobile;

    // Full-width header elements (above the split)
    final headerWidgets = <Widget>[
      if (isMobile) ...[
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Submission Details', style: AppTextStyles.h2),
                  Text(fapNumber, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
      Visibility(
        visible: false,
        child: _buildStatusCard(state, fapNumber),
      ),
      if (state.toLowerCase() == 'rejectedbyasm') ...[
        const SizedBox(height: 16),
        _buildRejectionCard(
          rejectedBy: 'ASM',
          reviewNotes: _submission!['asmReviewNotes']?.toString(),
        ),
      ],
      if (state.toLowerCase() == 'rejectedbyhq' ||
          state.toLowerCase() == 'rejectedbyra') ...[
        const SizedBox(height: 16),
        _buildRejectionCard(
          rejectedBy: 'RA',
          reviewNotes: _submission!['hqReviewNotes']?.toString(),
        ),
      ],
      if (state.toLowerCase() == 'processingfailed') ...[
        const SizedBox(height: 16),
        _buildProcessingFailedCard(),
      ],
      const SizedBox(height: 24),
      _buildPOSection(),
      const SizedBox(height: 24),
    ];

    // Main body content (sits beside the sidebar on desktop)
    final bodyContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_invoiceSummary != null)
          InvoiceSummarySection(data: _invoiceSummary!),
        const SizedBox(height: 24),
        Visibility(
          visible: false,
          child: CampaignDetailsTable(
          campaignDetails: _campaignDetails,
          onPhotoTap: (detail) =>
              _downloadDocument(detail.documentId, detail.documentName),
          ),
        ),
        _buildValidationReportSection(),
        ..._buildPhotoGallerySection(),
        const SizedBox(height: 80),
      ],
    );

    // Desktop/Tablet: header full-width, then 3/4 body + 1/4 sidebar aligned
    if (!isMobile) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(hPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...headerWidgets,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: bodyContent,
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.22,
                  child: _buildApprovalTimeline(),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Mobile: single column, timeline at the end
    return SingleChildScrollView(
      padding: EdgeInsets.all(hPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...headerWidgets,
          if (_invoiceSummary != null)
            InvoiceSummarySection(data: _invoiceSummary!),
          const SizedBox(height: 24),
          Visibility(
            visible: false,
            child: CampaignDetailsTable(
            campaignDetails: _campaignDetails,
            onPhotoTap: (detail) =>
                _downloadDocument(detail.documentId, detail.documentName),
            ),
          ),
          _buildValidationReportSection(),
          ..._buildPhotoGallerySection(),
          const SizedBox(height: 24),
          _buildApprovalTimeline(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String state, String fapNumber) {
    final statusInfo = _getStatusInfo(state);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusInfo['icon'], size: 32, color: statusInfo['color']),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fapNumber, style: AppTextStyles.h2),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusInfo['bgColor'],
                          border: Border.all(color: statusInfo['borderColor']),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusInfo['label'],
                          style: AppTextStyles.bodySmall.copyWith(
                            color: statusInfo['color'],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // PO Balance button
                if (widget.poNumber.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isLoadingBalance ? null : _fetchPOBalance,
                        icon: _isLoadingBalance
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.account_balance_wallet,
                                size: 16),
                        label: Text(
                            _poBalance != null ? 'Balance' : 'Check Balance'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      // Balance info below button
                      if (_poBalance != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${_poBalance!['currency'] ?? 'INR'} ${(_poBalance!['balance'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatBalanceDate(
                              _poBalance!['calculatedAt']?.toString()),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                      // Balance error below button
                      if (_balanceError != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Text(
                            _balanceError!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: const Color(0xFFDC2626),
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildInfoItem(
                        'Submitted', _formatDate(_submission!['createdAt']))),
                Expanded(
                    child: _buildInfoItem('Last Updated',
                        _formatDate(_submission!['updatedAt']))),
              ],
            ),
            // Submit button - show only for draft/uploaded states
            if (_canSubmit(state)) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitSubmission,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                      _isSubmitting ? 'Submitting...' : 'Submit for Review'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value,
            style:
                AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildPOSection() {
    if (_submission == null) return const SizedBox();
    final documents = _submission!['documents'] as List? ?? [];
    final poDocs = documents.where((d) => d['type'] == 'PO').toList();
    if (poDocs.isEmpty) return const SizedBox();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border)),
      child: ExpansionTile(
        leading:
            const Icon(Icons.description, color: Color(0xFF3B82F6), size: 32),
        title: const Text('Purchase Order', style: AppTextStyles.h3),
        subtitle: Text('${poDocs.length} document(s)'),
        children: poDocs.map((doc) {
          Map<String, dynamic>? data;
          final extractedData = doc['extractedData'];
          if (extractedData != null) {
            try {
              if (extractedData is String && extractedData.isNotEmpty) {
                data = Map<String, dynamic>.from(jsonDecode(extractedData));
              } else if (extractedData is Map) {
                data = Map<String, dynamic>.from(extractedData);
              }
            } catch (_) {}
          }
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.insert_drive_file, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        doc['filename'] ?? 'Unknown',
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download, size: 20),
                      onPressed: () => _downloadDocument(
                          doc['id']?.toString(), doc['filename']),
                      tooltip: 'Download',
                      color: AppColors.primary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                if (data != null) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: data.entries
                        .where((entry) => !const {
                              'LineItems',
                              'FieldConfidences',
                              'IsFlaggedForReview'
                            }.contains(entry.key))
                        .map((entry) {
                      return SizedBox(
                        width: 200,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatFieldName(entry.key),
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.value?.toString() ?? '-',
                              style: AppTextStyles.bodyMedium
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatFieldName(String key) {
    return key
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(0)}',
        )
        .trim()
        .split(' ')
        .map(
          (word) => word[0].toUpperCase() + word.substring(1),
        )
        .join(' ');
  }

  void _enterEditMode() {
    context.pushNamed('agency-upload', extra: {
      'token': widget.token,
      'userName': widget.userName,
      'submissionId': widget.submissionId,
    });
  }

  Widget _buildRejectionCard(
      {required String rejectedBy, String? reviewNotes}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFEF4444))),
      color: const Color(0xFFFEE2E2),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cancel, color: Color(0xFFEF4444), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Rejected by $rejectedBy',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
            if (reviewNotes != null && reviewNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Rejection Reason:',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFB91C1C),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  reviewNotes,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: const Color(0xFF7F1D1D)),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _enterEditMode,
                icon: const Icon(Icons.edit),
                label: const Text('Edit Submission'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingFailedCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFF59E0B))),
      color: const Color(0xFFFEF3C7),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber,
                    color: Color(0xFFF59E0B), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Processing Failed',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Document processing encountered an error. You can edit and resubmit.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: const Color(0xFF92400E)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _enterEditMode,
                icon: const Icon(Icons.edit),
                label: const Text('Edit & Resubmit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignsSection() {
    if (_submission == null) return const SizedBox();
    final campaigns = _submission!['campaigns'] as List? ?? [];
    if (campaigns.isEmpty) return const SizedBox();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.campaign, color: Color(0xFF3B82F6), size: 28),
                const SizedBox(width: 12),
                Text('Campaigns (${campaigns.length})',
                    style: AppTextStyles.h3),
              ],
            ),
          ),
          ...campaigns.asMap().entries.map((entry) {
            final campaign = entry.value as Map<String, dynamic>;
            return _buildCampaignTile(campaign, entry.key);
          }),
        ],
      ),
    );
  }

  Widget _buildCampaignTile(Map<String, dynamic> campaign, int index) {
    final name =
        campaign['campaignName']?.toString() ?? 'Campaign ${index + 1}';
    final teamCode = campaign['teamCode']?.toString() ?? '';
    final dealership = campaign['dealershipName']?.toString() ?? '';
    final startDate = _formatDate(campaign['startDate']);
    final endDate = _formatDate(campaign['endDate']);
    final workingDays = campaign['workingDays']?.toString() ?? '';
    final totalCost = campaign['totalCost'];
    final invoices = campaign['invoices'] as List? ?? [];
    final photos = campaign['photos'] as List? ?? [];
    final costSummaryUrl = campaign['costSummaryBlobUrl']?.toString();
    final costSummaryFile = campaign['costSummaryFileName']?.toString();
    final activitySummaryUrl = campaign['activitySummaryBlobUrl']?.toString();
    final activitySummaryFile = campaign['activitySummaryFileName']?.toString();
    final campaignId =
        campaign['id']?.toString() ?? campaign['campaignId']?.toString() ?? '';

    return ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF3B82F6).withOpacity(0.1),
        child: Text('${index + 1}',
            style: const TextStyle(
                color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
      ),
      title: Text(name,
          style:
              AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(
        [
          if (teamCode.isNotEmpty) 'Team: $teamCode',
          if (dealership.isNotEmpty) dealership
        ].join(' • '),
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
      ),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Campaign details row
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  if (startDate != 'N/A') _buildDetailChip('Start', startDate),
                  if (endDate != 'N/A') _buildDetailChip('End', endDate),
                  if (workingDays.isNotEmpty)
                    _buildDetailChip('Working Days', workingDays),
                  if (totalCost != null)
                    _buildDetailChip('Total Cost', '₹$totalCost'),
                ],
              ),
              const SizedBox(height: 16),

              // Cost Summary
              if (costSummaryUrl != null && costSummaryUrl.isNotEmpty)
                _buildDocumentRow(
                  Icons.summarize,
                  costSummaryFile ?? 'Cost Summary',
                  costSummaryUrl,
                ),

              // Activity Summary
              if (activitySummaryUrl != null && activitySummaryUrl.isNotEmpty)
                _buildDocumentRow(
                  Icons.assignment,
                  activitySummaryFile ?? 'Activity Summary',
                  activitySummaryUrl,
                ),

              // Invoices
              if (invoices.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Invoices (${invoices.length})',
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...invoices.map((inv) {
                  final invMap = inv as Map<String, dynamic>;
                  final invNum = invMap['invoiceNumber']?.toString() ?? '';
                  final vendor = invMap['vendorName']?.toString() ?? '';
                  final amount = invMap['totalAmount'];
                  final fileName = invMap['fileName']?.toString() ?? 'Invoice';
                  final blobUrl = invMap['blobUrl']?.toString() ?? '';
                  final label = [
                    fileName,
                    if (invNum.isNotEmpty) '(#$invNum)',
                    if (vendor.isNotEmpty) '- $vendor',
                    if (amount != null) '- ₹$amount',
                  ].join(' ');
                  return _buildDocumentRow(Icons.receipt, label, blobUrl);
                }),
              ],

              // Photos
              if (photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Photos (${photos.length})',
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...photos.map((photo) {
                  final photoMap = photo as Map<String, dynamic>;
                  final fileName = photoMap['fileName']?.toString() ?? 'Photo';
                  final blobUrl = photoMap['blobUrl']?.toString() ?? '';
                  final caption = photoMap['caption']?.toString() ?? '';
                  final label =
                      caption.isNotEmpty ? '$fileName - $caption' : fileName;
                  return _buildDocumentRow(Icons.image, label, blobUrl);
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditableDocumentRow(IconData icon, String label, String? blobUrl,
      {VoidCallback? onDelete}) {
    final hasUrl = blobUrl != null && blobUrl.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: hasUrl ? AppColors.primary : AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: AppTextStyles.bodyMedium,
                overflow: TextOverflow.ellipsis),
          ),
          if (hasUrl)
            IconButton(
              icon: const Icon(Icons.download, size: 18),
              onPressed: () => _downloadDocument(blobUrl, label),
              tooltip: 'Download',
              color: AppColors.primary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: onDelete,
              tooltip: 'Delete',
              color: AppColors.rejectedText,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadButton(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.upload_file, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildDetailChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style:
                AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDocumentRow(IconData icon, String label, String? blobUrl) {
    final hasUrl = blobUrl != null && blobUrl.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: hasUrl ? AppColors.primary : AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasUrl)
            IconButton(
              icon: const Icon(Icons.download, size: 18),
              onPressed: () => _downloadDocument(blobUrl, label),
              tooltip: 'Download',
              color: AppColors.primary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }

  Widget _buildApprovalTimeline() {
    final state = _submission!['state']?.toString().toLowerCase() ?? '';
    final createdAt = _submission!['createdAt'];
    final asmReviewedAt = _submission!['asmReviewedAt'];
    final asmReviewNotes = _submission!['asmReviewNotes']?.toString();
    final hqReviewedAt = _submission!['hqReviewedAt'];
    final hqReviewNotes = _submission!['hqReviewNotes']?.toString();

    // Determine ASM status
    String asmStatus = 'pending';
    if (state.contains('rejectedbyasm')) {
      asmStatus = 'rejected';
    } else if (state.contains('approved') ||
        state.contains('pendinghq') ||
        state.contains('rejectedbyhq')) {
      asmStatus = 'approved';
    } else if (asmReviewedAt != null) {
      asmStatus = asmReviewNotes != null && asmReviewNotes.isNotEmpty
          ? 'rejected'
          : 'approved';
    }

    // Determine HQ/RA status
    String hqStatus = 'pending';
    if (state == 'approved') {
      hqStatus = 'approved';
    } else if (state.contains('rejectedbyhq')) {
      hqStatus = 'rejected';
    } else if (hqReviewedAt != null) {
      hqStatus = hqReviewNotes != null && hqReviewNotes.isNotEmpty
          ? 'rejected'
          : 'approved';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Approval Flow', style: AppTextStyles.h3),
            const SizedBox(height: 20),
            // Step 1: Submitted
            _buildTimelineStep(
              icon: Icons.upload_file,
              color: const Color(0xFF3B82F6),
              title: 'Submitted',
              date: _formatDate(createdAt),
              comment: null,
              isCompleted: true,
              isLast: false,
            ),
            // Step 2: ASM Review
            _buildTimelineStep(
              icon: asmStatus == 'approved'
                  ? Icons.check_circle
                  : asmStatus == 'rejected'
                      ? Icons.cancel
                      : Icons.schedule,
              color: asmStatus == 'approved'
                  ? const Color(0xFF10B981)
                  : asmStatus == 'rejected'
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF9CA3AF),
              title: asmStatus == 'approved'
                  ? 'Approved by CH'
                  : asmStatus == 'rejected'
                      ? 'Rejected by CH'
                      : 'Pending CH Review',
              date: asmReviewedAt != null ? _formatDate(asmReviewedAt) : null,
              comment: asmReviewNotes,
              isCompleted: asmStatus != 'pending',
              isLast: false,
            ),
            // Step 3: HQ/RA Review
            _buildTimelineStep(
              icon: hqStatus == 'approved'
                  ? Icons.check_circle
                  : hqStatus == 'rejected'
                      ? Icons.cancel
                      : Icons.schedule,
              color: hqStatus == 'approved'
                  ? const Color(0xFF10B981)
                  : hqStatus == 'rejected'
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF9CA3AF),
              title: hqStatus == 'approved'
                  ? 'Approved by HQ/RA'
                  : hqStatus == 'rejected'
                      ? 'Rejected by HQ/RA'
                      : 'Pending HQ/RA Review',
              date: hqReviewedAt != null ? _formatDate(hqReviewedAt) : null,
              comment: hqReviewNotes,
              isCompleted: hqStatus != 'pending',
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep({
    required IconData icon,
    required Color color,
    required String title,
    String? date,
    String? comment,
    required bool isCompleted,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? color.withOpacity(0.15)
                        : const Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: isCompleted ? color : const Color(0xFFD1D5DB),
                        width: 2),
                  ),
                  child: Icon(icon,
                      size: 14,
                      color: isCompleted ? color : const Color(0xFF9CA3AF)),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isCompleted
                          ? color.withOpacity(0.3)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isCompleted
                          ? const Color(0xFF111827)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                  if (date != null) ...[
                    const SizedBox(height: 2),
                    Text(date,
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ],
                  if (comment != null && comment.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        comment,
                        style: AppTextStyles.bodySmall.copyWith(
                            color: const Color(0xFF4B5563), height: 1.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(String state) {
    final stateLower = state.toLowerCase();
    if (stateLower.contains('approved') && !stateLower.contains('pending')) {
      return {
        'label': 'Approved',
        'color': const Color(0xFF10B981),
        'bgColor': const Color(0xFFD1FAE5),
        'borderColor': const Color(0xFF6EE7B7),
        'icon': Icons.check_circle,
      };
    } else if (stateLower == 'rejectedbyasm') {
      return {
        'label': 'Rejected by CH',
        'color': const Color(0xFFDC2626),
        'bgColor': const Color(0xFFFEE2E2),
        'borderColor': const Color(0xFFFCA5A5),
        'icon': Icons.cancel,
      };
    } else if (stateLower == 'rejectedbyhq' || stateLower == 'rejectedbyra') {
      return {
        'label': 'Rejected by RA',
        'color': const Color(0xFFDC2626),
        'bgColor': const Color(0xFFFEE2E2),
        'borderColor': const Color(0xFFFCA5A5),
        'icon': Icons.cancel,
      };
    } else if (stateLower.contains('rejected')) {
      return {
        'label': 'Rejected',
        'color': const Color(0xFFDC2626),
        'bgColor': const Color(0xFFFEE2E2),
        'borderColor': const Color(0xFFFCA5A5),
        'icon': Icons.cancel,
      };
    } else if (stateLower.contains('pendinghq') ||
        stateLower == 'asmapproved') {
      return {
        'label': 'Pending with RA',
        'color': const Color(0xFF3B82F6),
        'bgColor': const Color(0xFFDBEAFE),
        'borderColor': const Color(0xFF93C5FD),
        'icon': Icons.hourglass_empty,
      };
    } else if (stateLower == 'processingfailed') {
      return {
        'label': 'Processing Failed',
        'color': const Color(0xFFF59E0B),
        'bgColor': const Color(0xFFFEF3C7),
        'borderColor': const Color(0xFFFCD34D),
        'icon': Icons.warning_amber,
      };
    } else if (stateLower.contains('pendingch') ||
        stateLower.contains('pendingapproval')) {
      return {
        'label': 'Pending with CH',
        'color': const Color(0xFFF59E0B),
        'bgColor': const Color(0xFFFEF3C7),
        'borderColor': const Color(0xFFFCD34D),
        'icon': Icons.schedule,
      };
    } else {
      return {
        'label': 'Processing',
        'color': const Color(0xFF6B7280),
        'bgColor': const Color(0xFFF3F4F6),
        'borderColor': const Color(0xFFD1D5DB),
        'icon': Icons.sync,
      };
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  String _getDocumentIdByType(String type) {
    final documents = _submission?['documents'] as List<dynamic>? ?? [];
    // Normalize for flexible matching
    final typeLower = type.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    for (final doc in documents) {
      final docType = (doc['type']?.toString() ?? doc['documentType']?.toString() ?? '')
          .toLowerCase().replaceAll(' ', '').replaceAll('_', '');
      if (docType == typeLower) {
        return doc['id']?.toString() ?? doc['documentId']?.toString() ?? '';
      }
    }
    return '';
  }

  /// Opens a blob URL in a new browser tab for viewing.
  void _openBlobUrl(String blobUrl, String filename) {
    if (blobUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document URL not available'), backgroundColor: Colors.orange),
      );
      return;
    }
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = blobUrl;
    anchor.target = '_blank';
    anchor.click();
  }

  /// Downloads a file directly from a blob URL.
  void _downloadByBlobUrl(String blobUrl, String filename) {
    if (blobUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document URL not available'), backgroundColor: Colors.orange),
      );
      return;
    }
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = blobUrl;
    anchor.download = filename;
    anchor.click();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloading $filename...'), backgroundColor: Color(0xFFFFFF)),
      );
    }
  }

  Future<void> _viewDocument(String documentId, String filename) async {
    try {
      final response = await _dioSilent.get(
        '/documents/$documentId/download',
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );
      if (response.statusCode == 200) {
        final base64Content = response.data['base64Content']?.toString() ?? '';
        final contentType = response.data['contentType']?.toString() ?? 'application/octet-stream';
        final name = response.data['filename']?.toString() ?? filename;
        if (base64Content.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File content not available'), backgroundColor: Colors.orange),
            );
          }
          return;
        }
        final bytes = base64.decode(base64Content);
        if (mounted) _showDocumentPreview(bytes, contentType, name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load document: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _downloadDocumentDirect(String? documentId, String? filename) async {
    if (documentId == null || documentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document not available for download'), backgroundColor: Colors.orange),
      );
      return;
    }
    try {
      final response = await _dioSilent.get(
        '/documents/$documentId/download',
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );
      if (response.statusCode == 200) {
        final base64Content = response.data['base64Content']?.toString() ?? '';
        final contentType = response.data['contentType']?.toString() ?? 'application/octet-stream';
        final name = filename ?? response.data['filename']?.toString() ?? 'document';
        if (base64Content.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File content not available'), backgroundColor: Colors.orange),
            );
          }
          return;
        }
        final bytes = base64.decode(base64Content);
        final blob = web.Blob(
          [Uint8List.fromList(bytes).toJS].toJS,
          web.BlobPropertyBag(type: contentType),
        );
        final url = web.URL.createObjectURL(blob);
        final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
        anchor.href = url;
        anchor.download = name;
        anchor.click();
        web.URL.revokeObjectURL(url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Downloading $name...'), backgroundColor: AppColors.approvedText, duration: const Duration(seconds: 2)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _downloadDocument(String? documentId, String? filename) async {
    if (documentId == null || documentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Document not available for download'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    try {
      final response = await _dioSilent.get(
        '/documents/$documentId/download',
        options: Options(
          headers: {'Authorization': 'Bearer ${widget.token}'},
        ),
      );

      if (response.statusCode == 200) {
        final base64Content = response.data['base64Content']?.toString() ?? '';
        final contentType = response.data['contentType']?.toString() ??
            'application/octet-stream';
        final name =
            filename ?? response.data['filename']?.toString() ?? 'document';

        if (base64Content.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('File content not available'),
                  backgroundColor: Colors.orange),
            );
          }
          return;
        }

        final bytes = base64.decode(base64Content);

        if (mounted) {
          _showDocumentPreview(bytes, contentType, name);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to download: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDocumentPreview(List<int> bytes, String contentType, String name) {
    final isImage = contentType.startsWith('image/');
    final isPdf = contentType == 'application/pdf';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.preview, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: isImage
                    ? InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Image.memory(
                          Uint8List.fromList(bytes),
                          fit: BoxFit.contain,
                        ),
                      )
                    : isPdf
                        ? _buildPdfPreview(bytes, contentType)
                        : Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.insert_drive_file,
                                      size: 64, color: AppColors.textSecondary),
                                  const SizedBox(height: 16),
                                  Text(name,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Preview not available for this file type.\nClick "Download" to save.',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        final blob = web.Blob(
                          [Uint8List.fromList(bytes).toJS].toJS,
                          web.BlobPropertyBag(type: contentType),
                        );
                        final url = web.URL.createObjectURL(blob);
                        final anchor = web.document.createElement('a')
                            as web.HTMLAnchorElement;
                        anchor.href = url;
                        anchor.download = name;
                        anchor.click();
                        web.URL.revokeObjectURL(url);
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Downloading $name...'),
                            backgroundColor: AppColors.approvedText,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPdfPreview(List<int> bytes, String contentType) {
    final blob = web.Blob(
      [Uint8List.fromList(bytes).toJS].toJS,
      web.BlobPropertyBag(type: contentType),
    );
    final url = web.URL.createObjectURL(blob);

    return SizedBox(
      width: double.infinity,
      height: 500,
      child: HtmlElementView.fromTagName(
        tagName: 'iframe',
        onElementCreated: (element) {
          final iframe = element as web.HTMLIFrameElement;
          iframe.src = url;
          iframe.style.border = 'none';
          iframe.style.width = '100%';
          iframe.style.height = '100%';
        },
      ),
    );
  }
}
