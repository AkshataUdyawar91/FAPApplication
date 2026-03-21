import 'package:pretty_dio_logger/pretty_dio_logger.dart';
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

  const AgencySubmissionDetailPage({
    super.key,
    required this.submissionId,
    required this.token,
    required this.userName,
    required this.poNumber,
  });

  @override
  ConsumerState<AgencySubmissionDetailPage> createState() =>
      _AgencySubmissionDetailPageState();
}

class _AgencySubmissionDetailPageState
    extends ConsumerState<AgencySubmissionDetailPage> {
  final _dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'))
    ..interceptors.add(PrettyDioLogger());

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

  @override
  void initState() {
    print('poNumber: ${widget.poNumber}');
    super.initState();
    _debugToken(); // Debug token contents
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

        print('=== JWT Token Debug ===');
        print('Token payload: $tokenData');
        print('Role claim: ${tokenData['role'] ?? 'NOT FOUND'}');
        print('Sub claim: ${tokenData['sub'] ?? 'NOT FOUND'}');
        print('Name claim: ${tokenData['name'] ?? 'NOT FOUND'}');
        print('All claims: ${tokenData.keys.toList()}');
        print('=====================');
      }
    } catch (e) {
      print('Error decoding token: $e');
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

        print('=== Validation Data from Submission ===');
        print('Invoice Validations Count: ${invoiceValidations.length}');
        print('Photo Validations Count: ${photoValidations.length}');
        print('Cost Summary Validation: ${costSummaryValidation.isNotEmpty}');
        print('Activity Validation: ${activityValidation.isNotEmpty}');
        print('Enquiry Validation: ${enquiryValidation.isNotEmpty}');
        if (invoiceValidations.isNotEmpty) {
          print('First Invoice Validation: ${invoiceValidations[0]}');
        }
        if (photoValidations.isNotEmpty) {
          print('First Photo Validation: ${photoValidations[0]}');
        }
        print('======================================');

        setState(() {
          _submission = submissionData;
          _invoiceSummary = invoiceSummary;
          _campaignDetails = campaignDetails;
          _invoiceValidations = invoiceValidations;
          _photoValidations = photoValidations;
          _costSummaryValidation = costSummaryValidation;
          _activityValidation = activityValidation;
          _enquiryValidation = enquiryValidation;
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
        print('PO Balance API Response: $balanceData'); // Debug log
        setState(() {
          _poBalance = balanceData;
          _isLoadingBalance = false;
        });
      }
    } catch (e) {
      print('PO Balance API Error: $e'); // Debug log
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
      print('Submit API Error: $e'); // Debug log
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
    // Allow submit for draft/uploaded states that haven't been submitted for review yet
    return stateLower == 'uploaded' ||
        stateLower == 'draft' ||
        stateLower == 'extracting' ||
        stateLower == 'validating' ||
        stateLower == 'validated' ||
        stateLower == 'scoring' ||
        stateLower == 'recommending';
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
    // Enquiry data is typically in a separate file or embedded in activity summary
    // Based on the API structure, it might be part of the activity summary or a separate document
    return 'Enquiry Data.xlsx'; // Default name, adjust based on actual API structure
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
                const Text('Document Validations', style: AppTextStyles.h3),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Invoice Validations (from invoiceValidations array)
            if (_invoiceValidations.isNotEmpty) ...[
              _buildInvoiceValidationsSection(_invoiceValidations),
              const SizedBox(height: 24),
            ],

            // Photo Validations
            if (_photoValidations.isNotEmpty) ...[
              _buildPhotoValidationsSection(_photoValidations),
              const SizedBox(height: 24),
            ],

            // Cost Summary Validation
            if (_costSummaryValidation.isNotEmpty) ...[
              _buildSingleValidationCard(
                title: 'Cost Summary Validation',
                fileName: _getCostSummaryFileName(),
                validation: _costSummaryValidation,
              ),
              const SizedBox(height: 24),
            ],

            // Activity Validation
            if (_activityValidation.isNotEmpty) ...[
              _buildSingleValidationCard(
                title: 'Activity Validation',
                fileName: _getActivitySummaryFileName(),
                validation: _activityValidation,
              ),
              const SizedBox(height: 24),
            ],

            // Enquiry Validation
            if (_enquiryValidation.isNotEmpty) ...[
              _buildSingleValidationCard(
                title: 'Enquiry Validation',
                fileName: _getEnquiryFileName(),
                validation: _enquiryValidation,
              ),
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

    Map<String, dynamic>? validationDetails;
    int passedCount = 0;
    int totalCount = 0;

    if (validationDetailsJson != null && validationDetailsJson.isNotEmpty) {
      try {
        validationDetails =
            jsonDecode(validationDetailsJson) as Map<String, dynamic>;

        // Calculate passed and total counts
        if (validationDetails != null) {
          final fieldPresence =
              validationDetails['fieldPresence'] as Map<String, dynamic>?;
          if (fieldPresence != null) {
            final missingFields =
                fieldPresence['missingFields'] as List<dynamic>? ?? [];
            totalCount += missingFields.length;
            // Missing fields are failed, so passedCount stays 0 for them
          }
        }
      } catch (e) {
        print('Error parsing validation details: $e');
      }
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(
          color: Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
                      Text(
                        'Invoice Validations',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fileName,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (totalCount > 0)
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$passedCount/$totalCount ',
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
              ],
            ),
          ),

          // Validation Details - Single unified table
          if (validationDetails != null)
            _buildUnifiedValidationTable(validationDetails),
        ],
      ),
    );
  }

  Widget _buildPhotoValidationsSection(List<dynamic> photoValidations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...photoValidations.map((photo) {
          final photoData = photo as Map<String, dynamic>;
          return _buildPhotoValidationCard(photoData);
        }),
      ],
    );
  }

  Widget _buildPhotoValidationCard(Map<String, dynamic> photo) {
    final fileName = photo['fileName'] ?? 'Unknown';
    final validationDetailsJson = photo['validationDetailsJson'] as String?;

    Map<String, dynamic>? validationDetails;
    int passedCount = 0;
    int totalCount = 0;

    if (validationDetailsJson != null && validationDetailsJson.isNotEmpty) {
      try {
        validationDetails =
            jsonDecode(validationDetailsJson) as Map<String, dynamic>;

        // Calculate passed and total counts for photo validations
        if (validationDetails != null) {
          final requiredItems =
              validationDetails['requiredItems'] as List<dynamic>? ?? [];
          totalCount = requiredItems.length;
          for (var item in requiredItems) {
            final itemMap = item as Map<String, dynamic>;
            final present = itemMap['present'] ?? false;
            if (present) passedCount++;
          }
        }
      } catch (e) {
        print('Error parsing validation details: $e');
      }
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(
          color: Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                      Text(
                        'Photo Validations',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fileName,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (totalCount > 0)
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$passedCount/$totalCount ',
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
              ],
            ),
          ),

          // Validation Details - Single unified table
          if (validationDetails != null)
            _buildUnifiedValidationTable(validationDetails),
        ],
      ),
    );
  }

  Widget _buildUnifiedValidationTable(Map<String, dynamic> validationDetails) {
    // Collect all validations into a single list
    List<Map<String, dynamic>> allValidations = [];

    // Add missing fields from fieldPresence (for invoice validations)
    if (validationDetails['fieldPresence'] != null) {
      final fieldPresence =
          validationDetails['fieldPresence'] as Map<String, dynamic>;
      final missingFields =
          fieldPresence['missingFields'] as List<dynamic>? ?? [];

      // Create a row for each missing field
      for (var field in missingFields) {
        allValidations.add({
          'field': field.toString(),
          'label': field.toString(),
          'passed': false,
          'message': 'Field is missing',
        });
      }
    }

    // Add proactive validations
    if (validationDetails['proactive'] != null) {
      final proactive = validationDetails['proactive'] as List<dynamic>;
      allValidations.addAll(proactive.map((v) => v as Map<String, dynamic>));
    }

    // Add reactive validations
    if (validationDetails['reactive'] != null) {
      final reactive = validationDetails['reactive'] as List<dynamic>;
      allValidations.addAll(reactive.map((v) => v as Map<String, dynamic>));
    }

    // Add checks
    if (validationDetails['checks'] != null) {
      final checks = validationDetails['checks'] as List<dynamic>;
      allValidations.addAll(checks.map((v) => v as Map<String, dynamic>));
    }

    // Add required items (for photos)
    if (validationDetails['requiredItems'] != null) {
      final items = validationDetails['requiredItems'] as List<dynamic>;
      allValidations.addAll(items.map((v) => v as Map<String, dynamic>));
    }

    if (allValidations.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            // borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'WHAT WAS CHECKED',
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
                  'RESULT',
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
                  'WHAT WAS FOUND',
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
        ...allValidations.asMap().entries.map((entry) {
          final index = entry.key;
          final validation = entry.value;
          final isLast = index == allValidations.length - 1;

          final field = validation['field'] ?? validation['item'] ?? 'Unknown';
          final passed = validation['passed'] ?? false;
          final value = validation['value'];
          final message = validation['message'];
          final label = validation['label'];
          final confidence = validation['confidence'];
          final present = validation['present'];

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
                  child: Text(
                    passed ? 'Pass' : 'Fail',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(width: 12),

                // Column 3: What was found
                Expanded(
                  flex: 3,
                  child: _buildWhatWasFoundColumn(
                    value: value,
                    message: message,
                    confidence: confidence,
                    present: present,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWhatWasFoundColumn({
    dynamic value,
    dynamic message,
    dynamic confidence,
    dynamic present,
  }) {
    // Handle required items with confidence
    if (confidence != null) {
      final isPresent = present ?? false;
      return Row(
        children: [
          Text(
            isPresent ? 'Detected with ' : 'Not detected, ',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getConfidenceColor((confidence as num).toDouble() * 100)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color:
                    _getConfidenceColor((confidence as num).toDouble() * 100),
                width: 0.5,
              ),
            ),
            child: Text(
              '${((confidence as num) * 100).toStringAsFixed(0)}% confidence',
              style: AppTextStyles.bodySmall.copyWith(
                color:
                    _getConfidenceColor((confidence as num).toDouble() * 100),
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
        ],
      );
    }

    // Handle regular validations
    return Column(
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
    );
  }

  Widget _buildSingleValidationCard({
    required String title,
    String? fileName,
    required Map<String, dynamic> validation,
  }) {
    final validationDetailsJson =
        validation['validationDetailsJson'] as String?;

    Map<String, dynamic>? validationDetails;
    int passedCount = 0;
    int totalCount = 0;

    if (validationDetailsJson != null && validationDetailsJson.isNotEmpty) {
      try {
        validationDetails =
            jsonDecode(validationDetailsJson) as Map<String, dynamic>;

        // Calculate passed and total counts
        if (validationDetails != null) {
          // Count field presence checks
          final fieldPresence =
              validationDetails['fieldPresence'] as Map<String, dynamic>?;
          if (fieldPresence != null) {
            final missingFields =
                fieldPresence['missingFields'] as List<dynamic>? ?? [];
            final totalRecords = fieldPresence['totalRecords'];

            // Count missing fields
            totalCount += missingFields.length;

            // Count enquiry field validations
            if (totalRecords != null) {
              final recordsWithState = fieldPresence['recordsWithState'];
              final recordsWithDate = fieldPresence['recordsWithDate'];
              final recordsWithDealerCode =
                  fieldPresence['recordsWithDealerCode'];
              final recordsWithDealerName =
                  fieldPresence['recordsWithDealerName'];
              final recordsWithDistrict = fieldPresence['recordsWithDistrict'];
              final recordsWithPincode = fieldPresence['recordsWithPincode'];
              final recordsWithCustomerName =
                  fieldPresence['recordsWithCustomerName'];
              final recordsWithCustomerNumber =
                  fieldPresence['recordsWithCustomerNumber'];
              final recordsWithTestRide = fieldPresence['recordsWithTestRide'];

              if (recordsWithState != null) {
                totalCount++;
                if (recordsWithState == totalRecords) passedCount++;
              }
              if (recordsWithDate != null) {
                totalCount++;
                if (recordsWithDate == totalRecords) passedCount++;
              }
              if (recordsWithDealerCode != null) {
                totalCount++;
                if (recordsWithDealerCode == totalRecords) passedCount++;
              }
              if (recordsWithDealerName != null) {
                totalCount++;
                if (recordsWithDealerName == totalRecords) passedCount++;
              }
              if (recordsWithDistrict != null) {
                totalCount++;
                if (recordsWithDistrict == totalRecords) passedCount++;
              }
              if (recordsWithPincode != null) {
                totalCount++;
                if (recordsWithPincode == totalRecords) passedCount++;
              }
              if (recordsWithCustomerName != null) {
                totalCount++;
                if (recordsWithCustomerName == totalRecords) passedCount++;
              }
              if (recordsWithCustomerNumber != null) {
                totalCount++;
                if (recordsWithCustomerNumber == totalRecords) passedCount++;
              }
              if (recordsWithTestRide != null) {
                totalCount++;
                if (recordsWithTestRide == totalRecords) passedCount++;
              }
            }
          }

          // Count cross-document checks
          final crossDocument =
              validationDetails['crossDocument'] as Map<String, dynamic>?;
          if (crossDocument != null) {
            final totalCostValid = crossDocument['totalCostValid'];
            final elementCostsValid = crossDocument['elementCostsValid'];
            final fixedCostsValid = crossDocument['fixedCostsValid'];
            final variableCostsValid = crossDocument['variableCostsValid'];
            final numberOfDaysMatches = crossDocument['numberOfDaysMatches'];

            if (totalCostValid != null) {
              totalCount++;
              if (totalCostValid == true) passedCount++;
            }
            if (elementCostsValid != null) {
              totalCount++;
              if (elementCostsValid == true) passedCount++;
            }
            if (fixedCostsValid != null) {
              totalCount++;
              if (fixedCostsValid == true) passedCount++;
            }
            if (variableCostsValid != null) {
              totalCount++;
              if (variableCostsValid == true) passedCount++;
            }
            if (numberOfDaysMatches != null) {
              totalCount++;
              if (numberOfDaysMatches == true) passedCount++;
            }

            // Count issues
            final issues = crossDocument['issues'] as List<dynamic>? ?? [];
            totalCount += issues.length;
          }
        }
      } catch (e) {
        print('Error parsing validation details: $e');
      }
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(
          color: Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
                      Text(
                        title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (fileName != null && fileName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          fileName,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (totalCount > 0)
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$passedCount/$totalCount ',
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
              ],
            ),
          ),

          // Validation Details Table (if available)
          if (validationDetails != null)
            _buildSimpleValidationDetailsTable(validationDetails),
        ],
      ),
    );
  }

  Widget _buildSimpleValidationDetailsTable(
      Map<String, dynamic> validationDetails) {
    // Extract field presence and cross-document checks
    final fieldPresence =
        validationDetails['fieldPresence'] as Map<String, dynamic>?;
    final crossDocument =
        validationDetails['crossDocument'] as Map<String, dynamic>?;

    List<Map<String, dynamic>> rows = [];

    // Add field presence checks - ONE ROW PER MISSING FIELD
    if (fieldPresence != null) {
      final allFieldsPresent = fieldPresence['allFieldsPresent'] ?? true;
      final missingFields =
          fieldPresence['missingFields'] as List<dynamic>? ?? [];
      final totalRecords = fieldPresence['totalRecords'];

      // For enquiry validation (has totalRecords), don't add missingFields
      // because we'll add individual field checks below
      if (totalRecords == null &&
          !allFieldsPresent &&
          missingFields.isNotEmpty) {
        // This is for Invoice/Cost Summary/Activity validations
        // Create a separate row for each missing field
        for (var field in missingFields) {
          rows.add({
            'label': field.toString(),
            'passed': false,
            'message': 'Field is missing',
          });
        }
      }

      // Add other field presence details if available (for enquiry validation)
      if (totalRecords != null) {
        // Show ALL fields with their pass/fail status
        final recordsWithState = fieldPresence['recordsWithState'];
        final recordsWithDate = fieldPresence['recordsWithDate'];
        final recordsWithDealerCode = fieldPresence['recordsWithDealerCode'];
        final recordsWithDealerName = fieldPresence['recordsWithDealerName'];
        final recordsWithDistrict = fieldPresence['recordsWithDistrict'];
        final recordsWithPincode = fieldPresence['recordsWithPincode'];
        final recordsWithCustomerName =
            fieldPresence['recordsWithCustomerName'];
        final recordsWithCustomerNumber =
            fieldPresence['recordsWithCustomerNumber'];
        final recordsWithTestRide = fieldPresence['recordsWithTestRide'];

        // Add all fields with their status
        if (recordsWithState != null) {
          rows.add({
            'label': 'State',
            'passed': recordsWithState == totalRecords,
            'message': 'Present in $recordsWithState/$totalRecords records',
          });
        }
        if (recordsWithDate != null) {
          rows.add({
            'label': 'Date',
            'passed': recordsWithDate == totalRecords,
            'message': 'Present in $recordsWithDate/$totalRecords records',
          });
        }
        if (recordsWithDealerCode != null) {
          rows.add({
            'label': 'Dealer Code',
            'passed': recordsWithDealerCode == totalRecords,
            'message':
                'Present in $recordsWithDealerCode/$totalRecords records',
          });
        }
        if (recordsWithDealerName != null) {
          rows.add({
            'label': 'Dealer Name',
            'passed': recordsWithDealerName == totalRecords,
            'message':
                'Present in $recordsWithDealerName/$totalRecords records',
          });
        }
        if (recordsWithDistrict != null) {
          rows.add({
            'label': 'District',
            'passed': recordsWithDistrict == totalRecords,
            'message': 'Present in $recordsWithDistrict/$totalRecords records',
          });
        }
        if (recordsWithPincode != null) {
          rows.add({
            'label': 'Pincode',
            'passed': recordsWithPincode == totalRecords,
            'message': 'Present in $recordsWithPincode/$totalRecords records',
          });
        }
        if (recordsWithCustomerName != null) {
          rows.add({
            'label': 'Customer Name',
            'passed': recordsWithCustomerName == totalRecords,
            'message':
                'Present in $recordsWithCustomerName/$totalRecords records',
          });
        }
        if (recordsWithCustomerNumber != null) {
          rows.add({
            'label': 'Customer Number',
            'passed': recordsWithCustomerNumber == totalRecords,
            'message':
                'Present in $recordsWithCustomerNumber/$totalRecords records',
          });
        }
        if (recordsWithTestRide != null) {
          rows.add({
            'label': 'Test Ride',
            'passed': recordsWithTestRide == totalRecords,
            'message': 'Present in $recordsWithTestRide/$totalRecords records',
          });
        }
      }
    }

    // Add cross-document checks
    if (crossDocument != null) {
      // Add specific validation checks
      final totalCostValid = crossDocument['totalCostValid'];
      final elementCostsValid = crossDocument['elementCostsValid'];
      final fixedCostsValid = crossDocument['fixedCostsValid'];
      final variableCostsValid = crossDocument['variableCostsValid'];
      final numberOfDaysMatches = crossDocument['numberOfDaysMatches'];

      if (totalCostValid != null) {
        rows.add({
          'label': 'Total Cost Validation',
          'passed': totalCostValid,
          'message': totalCostValid
              ? 'Total cost matches invoice'
              : 'Total cost does not match invoice',
        });
      }

      if (elementCostsValid != null) {
        rows.add({
          'label': 'Element Costs Validation',
          'passed': elementCostsValid,
          'message': elementCostsValid
              ? 'Element costs are valid'
              : 'Element costs are invalid',
        });
      }

      if (fixedCostsValid != null) {
        rows.add({
          'label': 'Fixed Costs Validation',
          'passed': fixedCostsValid,
          'message': fixedCostsValid
              ? 'Fixed costs are valid'
              : 'Fixed costs are invalid',
        });
      }

      if (variableCostsValid != null) {
        rows.add({
          'label': 'Variable Costs Validation',
          'passed': variableCostsValid,
          'message': variableCostsValid
              ? 'Variable costs are valid'
              : 'Variable costs are invalid',
        });
      }

      if (numberOfDaysMatches != null) {
        rows.add({
          'label': 'Number of Days Match',
          'passed': numberOfDaysMatches,
          'message': numberOfDaysMatches
              ? 'Number of days matches between documents'
              : 'Number of days mismatch between documents',
        });
      }

      // Add issues as separate rows
      final issues = crossDocument['issues'] as List<dynamic>? ?? [];
      for (var issue in issues) {
        rows.add({
          'label': 'Cross-document Issue',
          'passed': false,
          'message': issue.toString(),
        });
      }
    }

    if (rows.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table Header
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
                child: Text(
                  'WHAT WAS CHECKED',
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
                  'RESULT',
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
                  'WHAT WAS FOUND',
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
                    label,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Column 2: Status
                SizedBox(
                  width: 80,
                  child: Text(
                    passed ? 'Pass' : 'Fail',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(width: 12),

                // Column 3: What was found
                Expanded(
                  flex: 3,
                  child: Text(
                    message,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: passed
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                      fontStyle: passed ? FontStyle.normal : FontStyle.italic,
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
                  'WHAT WAS CHECKED',
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
                  'RESULT',
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
                  'WHAT WAS FOUND',
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
                  'WHAT WAS CHECKED',
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
                  'RESULT',
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
                  'WHAT WAS FOUND',
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
      'submissionId': widget.submissionId,
    });
  }

  List<NavItem> _getNavItems(BuildContext context) {
    return [
      NavItem(
          icon: Icons.dashboard,
          label: 'Dashboard',
          onTap: () => Navigator.pop(context)),
      NavItem(
          icon: Icons.upload_file, label: 'Upload', onTap: _navigateToUpload),
      NavItem(
          icon: Icons.visibility,
          label: 'View Request',
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
          CircleAvatar(
            backgroundColor: Colors.white,
            radius: 18,
            child: Text(
              widget.userName.isNotEmpty
                  ? widget.userName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: Color(0xFF003087),
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.userName,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              const SizedBox(height: 2),
              Text('Agency',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7))),
            ],
          ),
          const SizedBox(width: 12),
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
          appBar: isMobile
              ? AppBar(
                  backgroundColor: const Color(0xFF1E3A8A),
                  title: const Text('Bajaj',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  iconTheme: const IconThemeData(color: Colors.white),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Back to Dashboard',
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

  Widget _buildDesktopHeader(DeviceType device) {
    final fapNumber =
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
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back to Dashboard',
          ),
          const SizedBox(width: 8),
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
    final fapNumber =
        'FAP-${widget.submissionId.length >= 8 ? widget.submissionId.substring(0, 8).toUpperCase() : widget.submissionId.toUpperCase()}';
    final hPad = responsiveValue<double>(MediaQuery.of(context).size.width,
        mobile: 12, tablet: 16, desktop: 24);

    return SingleChildScrollView(
      padding: EdgeInsets.all(hPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (device == DeviceType.mobile) ...[
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
          _buildStatusCard(state, fapNumber),
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

          // Invoice Summary Section (ASM-style)
          if (_invoiceSummary != null)
            InvoiceSummarySection(data: _invoiceSummary!),
          const SizedBox(height: 24),

          // Campaign Details Table (ASM-style)
          CampaignDetailsTable(
            campaignDetails: _campaignDetails,
            onPhotoTap: (detail) =>
                _downloadDocument(detail.documentId, detail.documentName),
          ),
          const SizedBox(height: 24),

          // Validation Report API Result Section
          _buildValidationReportSection(),

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
      final response = await _dio.get(
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
