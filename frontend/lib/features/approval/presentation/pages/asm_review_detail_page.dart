import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
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
import '../../data/models/invoice_summary_data.dart';
import '../../data/models/invoice_document_row.dart';
import '../utils/submission_data_transformer.dart';
import '../widgets/invoice_summary_section.dart';
import '../widgets/invoice_documents_table.dart';
import '../widgets/campaign_details_table.dart';
import '../widgets/ai_analysis_section.dart';
import '../../data/models/campaign_detail_row.dart';

class ASMReviewDetailPage extends ConsumerStatefulWidget {
  final String submissionId;
  final String token;
  final String userName;

  const ASMReviewDetailPage({
    super.key,
    required this.submissionId,
    required this.token,
    required this.userName,
  });

  @override
  ConsumerState<ASMReviewDetailPage> createState() =>
      _ASMReviewDetailPageState();
}

class _ASMReviewDetailPageState extends ConsumerState<ASMReviewDetailPage> {
  final _dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:5000/api',
      // Disable caching
      headers: {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      },
    ),
  )..interceptors.add(PrettyDioLogger());
  final _commentsController = TextEditingController();

  bool _isLoading = true;
  Map<String, dynamic>? _submission;
  bool _isProcessing = false;
  bool _isChatOpen = false;
  bool _isSidebarCollapsed = true;

  // Transformed data for new layout
  InvoiceSummaryData? _invoiceSummary;
  List<InvoiceDocumentRow> _invoiceDocuments = [];
  List<CampaignDetailRow> _campaignDetails = [];

  // Validation data from submission response
  List<dynamic> _invoiceValidations = [];
  List<dynamic> _photoValidations = [];
  Map<String, dynamic> _costSummaryValidation = {};
  Map<String, dynamic> _activityValidation = {};
  Map<String, dynamic> _enquiryValidation = {};

  @override
  void initState() {
    super.initState();
    _loadSubmissionDetails();
  }

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _loadSubmissionDetails() async {
    setState(() => _isLoading = true);

    try {
      // Add timestamp to prevent caching
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await _dio.get(
        '/submissions/${widget.submissionId}?_t=$timestamp',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${widget.token}',
            'Cache-Control': 'no-cache',
          },
        ),
      );

      if (response.statusCode == 200 && mounted) {
        final submissionData = response.data as Map<String, dynamic>;

        // Transform data for new layout (uses failureReason from submission directly)
        final invoiceSummary =
            SubmissionDataTransformer.extractInvoiceSummary(submissionData);
        final invoiceDocuments =
            SubmissionDataTransformer.transformToInvoiceDocuments(
                submissionData);
        final campaignDetails =
            SubmissionDataTransformer.transformToCampaignDetails(
                submissionData);

        // Fetch hierarchical campaign data for photos, cost summary, activity summary
        // These docs aren't in the submission's documents array
        List<CampaignDetailRow> hierRows = [];
        try {
          final hierResponse = await _dio.get(
            '/hierarchical/${widget.submissionId}/structure',
            options:
                Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
          );
          if (hierResponse.statusCode == 200 && hierResponse.data != null) {
            final campaigns = hierResponse.data['campaigns'] as List? ?? [];
            hierRows = _buildHierarchicalRows(campaigns, submissionData);
          }
        } catch (e) {
          debugPrint('Failed to load hierarchical data: $e');
        }

        // Merge: submission docs + hierarchical docs (avoid duplicates by filename)
        final allCampaignDetails =
            _mergeCampaignDetails(campaignDetails, hierRows);

        // Extract validation data from submission response
        final invoiceValidations =
            submissionData['invoiceValidations'] as List<dynamic>? ?? [];
        var photoValidations =
            submissionData['photoValidations'] as List<dynamic>? ?? [];
        final costSummaryValidation =
            submissionData['costSummaryValidation'] as Map<String, dynamic>? ??
                {};
        final activityValidation =
            submissionData['activityValidation'] as Map<String, dynamic>? ?? {};
        final enquiryValidation =
            submissionData['enquiryValidation'] as Map<String, dynamic>? ?? {};

        // Fallback: if photoValidations is empty, fetch directly by package ID
        // (TeamPhoto validation is stored with DocumentId = packageId)
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
          } catch (e) {
            debugPrint('Fallback photo validation fetch failed: $e');
          }
        }

        print('=== ASM - Validation Data from Submission ===');
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
          _invoiceDocuments = invoiceDocuments;
          _campaignDetails = allCampaignDetails;
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
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load submission: ${e.toString()}'),
            backgroundColor: AppColors.rejectedText,
          ),
        );
      }
    }
  }

  Future<void> _approveSubmission() async {
    setState(() => _isProcessing = true);

    try {
      final response = await _dio.patch(
        '/submissions/${widget.submissionId}/asm-approve',
        data: {'notes': _commentsController.text.trim()},
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('FAP approved and sent to HQ'),
            backgroundColor: AppColors.approvedText,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve: ${e.toString()}'),
            backgroundColor: AppColors.rejectedText,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _rejectSubmission(String reason) async {
    setState(() => _isProcessing = true);

    try {
      final response = await _dio.patch(
        '/submissions/${widget.submissionId}/asm-reject',
        data: {'Reason': reason}, // Capital R to match backend DTO
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('FAP rejected (sent back to Agency)'),
            backgroundColor: AppColors.rejectedText,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject: ${e.toString()}'),
            backgroundColor: AppColors.rejectedText,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showRejectDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject FAP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide a reason for rejection:',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a rejection reason'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _rejectSubmission(reason);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  List<NavItem> _getNavItems(BuildContext context) {
    return [
      NavItem(
          icon: Icons.dashboard,
          label: 'Dashboard',
          onTap: () => Navigator.pop(context)),
      NavItem(
          icon: Icons.rate_review,
          label: 'Review',
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
                letterSpacing: 0.5),
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
              Text('ASM',
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
          backgroundColor: AppColors.background,
          appBar: isMobile
              ? AppBar(
                  backgroundColor: const Color(0xFF1E3A8A),
                  title: const Text('Bajaj',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  iconTheme: const IconThemeData(color: Colors.white),
                  actions: const [],
                )
              : null,
          drawer: isMobile
              ? AppDrawer(
                  userName: widget.userName,
                  userRole: 'ASM',
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
                        userRole: 'ASM',
                        navItems: _getNavItems(context),
                        onLogout: () => handleLogout(context, ref),
                        isCollapsed: _isSidebarCollapsed,
                        onToggleCollapse: () => setState(
                            () => _isSidebarCollapsed = !_isSidebarCollapsed),
                      ),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _submission == null
                              ? const Center(
                                  child: Text('Submission not found'))
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildHeaderSection(),
                                      const SizedBox(height: 24),
                                      if (_invoiceSummary != null)
                                        InvoiceSummarySection(
                                            data: _invoiceSummary!),
                                      const SizedBox(height: 24),
                                      AiAnalysisSection(
                                          submission: _submission!),
                                      const SizedBox(height: 24),
                                      InvoiceDocumentsTable(
                                        documents: _invoiceDocuments,
                                        onDocumentTap: (doc) {
                                          if (doc.documentId != null &&
                                              doc.documentId!.isNotEmpty) {
                                            _downloadDocument(doc.documentId,
                                                doc.documentName);
                                          } else {
                                            _downloadDocumentByUrl(
                                                doc.blobUrl, doc.documentName);
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 24),
                                      CampaignDetailsTable(
                                        campaignDetails: _campaignDetails,
                                        onPhotoTap: (detail) {
                                          if (detail.downloadPath != null &&
                                              detail.downloadPath!.isNotEmpty) {
                                            _downloadHierarchicalDocument(
                                                detail.downloadPath!,
                                                detail.documentName);
                                          } else if (detail.documentId !=
                                                  null &&
                                              detail.documentId!.isNotEmpty) {
                                            _downloadDocument(detail.documentId,
                                                detail.documentName);
                                          } else {
                                            _downloadDocumentByUrl(
                                                detail.blobUrl,
                                                detail.documentName);
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 24),
                                      _buildValidationReportSection(),
                                      const SizedBox(height: 80),
                                    ],
                                  ),
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

  Widget _buildHeaderSection() {
    final documents = _submission!['documents'] as List? ?? [];
    String invoiceNumber = '';
    String reqNumber = _submission!['submissionNumber']?.toString() 
        ?? 'REQ-${widget.submissionId.substring(0, 8).toUpperCase()}';
    
    // Extract invoice number from invoice document
    for (var doc in documents) {
      if (doc['type'] == 'Invoice' && doc['extractedData'] != null) {
        try {
          final extractedData = doc['extractedData'];
          Map<String, dynamic>? data;
          if (extractedData is String) {
            data = jsonDecode(extractedData);
          } else if (extractedData is Map) {
            data = Map<String, dynamic>.from(extractedData);
          }
          if (data != null) {
            invoiceNumber =
                data['InvoiceNumber'] ?? data['invoiceNumber'] ?? '';
            break;
          }
        } catch (e) {
          // Keep default empty string
        }
      }
    }

    final agencyName = _invoiceSummary?.agencyName ?? '';
    final submittedDate = _submission!['createdAt'];
    final state = _submission!['state']?.toString() ?? 'Unknown';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button and title row
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to review list',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoiceNumber.isNotEmpty && agencyName.isNotEmpty
                            ? '$invoiceNumber - $agencyName'
                            : invoiceNumber.isNotEmpty
                                ? invoiceNumber
                                : agencyName.isNotEmpty
                                    ? agencyName
                                    : 'Submission Details',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            reqNumber,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                _formatDisplayDate(submittedDate),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(state),
              ],
            ),
            const SizedBox(height: 20),

            // Action buttons row - only show for actionable states
            if (_isSubmissionActionable()) ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: _isProcessing ? null : _showRejectDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Reject'),
                  ),
                  ElevatedButton(
                    onPressed: _isProcessing ? null : _approveSubmission,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Approve Request'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Comments section in header
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Comments (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentsController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add your review comments here...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String state) {
    final normalizedState = state.toLowerCase();

    Color backgroundColor;
    Color textColor;
    String displayText;

    if (normalizedState == 'pendingch' || normalizedState == 'pendingapproval' || normalizedState == 'pendingchapproval') {
      backgroundColor = const Color(0xFFDEEAFF);
      textColor = const Color(0xFF0066FF);
      displayText = 'Pending';
    } else if (normalizedState == 'pendingra' || normalizedState == 'asmapproved' || normalizedState == 'pendinghqapproval') {
      backgroundColor = const Color(0xFFDEEAFF);
      textColor = const Color(0xFF0066FF);
      displayText = 'Pending with RA';
    } else if (normalizedState == 'approved') {
      backgroundColor = const Color(0xFFD1FAE5);
      textColor = const Color(0xFF10B981);
      displayText = 'Approved';
    } else if (normalizedState == 'rarejected' || normalizedState == 'rejectedbyhq' || normalizedState == 'rejectedbyra') {
      backgroundColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFEF4444);
      displayText = 'Rejected by RA';
    } else if (normalizedState == 'chrejected' || normalizedState == 'rejectedbyasm' || normalizedState == 'rejected') {
      backgroundColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFEF4444);
      displayText = 'Rejected';
    } else {
      backgroundColor = const Color(0xFFF3F4F6);
      textColor = const Color(0xFF6B7280);
      displayText = state;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  String _formatDisplayDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date.toString());
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (e) {
      return '';
    }
  }

  bool _isSubmissionActionable() {
    final state = _submission?['state']?.toString().toLowerCase() ?? '';
    return state == 'pendingch' || 
           state == 'pendingapproval' || 
           state == 'pendingchapproval' ||
           state == 'rarejected';
  }

  /// Builds CampaignDetailRow list from hierarchical campaign data.
  List<CampaignDetailRow> _buildHierarchicalRows(
    List<dynamic> campaigns,
    Map<String, dynamic> submissionData,
  ) {
    final failureReason =
        submissionData['validationResult']?['failureReason']?.toString() ?? '';
    final allPassed =
        submissionData['validationResult']?['allValidationsPassed'] == true;
    final rows = <CampaignDetailRow>[];
    int serial = 1;

    for (final campaign in campaigns) {
      final photos = (campaign['photos'] as List?) ?? [];
      final costFile = campaign['costSummaryFileName']?.toString();
      final activityFile = campaign['activitySummaryFileName']?.toString();

      for (final photo in photos) {
        final fileName = photo['fileName']?.toString() ?? '-';
        final remarks = SubmissionDataTransformer.buildRemarksFromFailureReason(
            'Photo', failureReason, allPassed);
        rows.add(
          CampaignDetailRow(
            serialNumber: serial++,
            dealerName: 'Photo',
            campaignDate: '',
            documentName: fileName,
            status: allPassed
                ? ValidationStatus.ok
                : (remarks.isNotEmpty
                    ? ValidationStatus.failed
                    : ValidationStatus.ok),
            remarks: remarks,
            documentId: photo['photoId']?.toString(),
          ),
        );
      }

      if (costFile != null && costFile.isNotEmpty) {
        final remarks = SubmissionDataTransformer.buildRemarksFromFailureReason(
            'CostSummary', failureReason, allPassed);
        rows.add(
          CampaignDetailRow(
            serialNumber: serial++,
            dealerName: 'CostSummary',
            campaignDate: '',
            documentName: costFile,
            status: allPassed
                ? ValidationStatus.ok
                : (remarks.isNotEmpty
                    ? ValidationStatus.failed
                    : ValidationStatus.ok),
            remarks: remarks,
          ),
        );
      }

      if (activityFile != null && activityFile.isNotEmpty) {
        final remarks = SubmissionDataTransformer.buildRemarksFromFailureReason(
            'Activity', failureReason, allPassed);
        rows.add(
          CampaignDetailRow(
            serialNumber: serial++,
            dealerName: 'Activity',
            campaignDate: '',
            documentName: activityFile,
            status: allPassed
                ? ValidationStatus.ok
                : (remarks.isNotEmpty
                    ? ValidationStatus.failed
                    : ValidationStatus.ok),
            remarks: remarks,
          ),
        );
      }
    }

    return rows;
  }

  /// Merges submission-based campaign details with hierarchical rows.
  /// Avoids duplicates by checking document names.
  List<CampaignDetailRow> _mergeCampaignDetails(
    List<CampaignDetailRow> fromSubmission,
    List<CampaignDetailRow> fromHierarchical,
  ) {
    final existingNames =
        fromSubmission.map((r) => r.documentName.toLowerCase()).toSet();
    final merged = List<CampaignDetailRow>.from(fromSubmission);

    for (final row in fromHierarchical) {
      if (!existingNames.contains(row.documentName.toLowerCase())) {
        merged.add(row.copyWith(serialNumber: merged.length + 1));
        existingNames.add(row.documentName.toLowerCase());
      }
    }

    return merged;
  }

  void _downloadDocumentByUrl(String? blobUrl, String? filename) {
    if (blobUrl == null || blobUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Document URL not available'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    try {
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = blobUrl;
      anchor.target = '_blank';
      anchor.click();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening ${filename ?? 'document'}...'),
            backgroundColor: AppColors.approvedText,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to open document: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _downloadHierarchicalDocument(
      String path, String? filename) async {
    try {
      final response = await _dio.get(
        path,
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

        final blob = web.Blob(
          [bytes.toJS].toJS,
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
            SnackBar(
              content: Text('Downloading $name...'),
              backgroundColor: AppColors.approvedText,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadDocument(String? documentId, String? filename) async {
    if (documentId == null || documentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document not available for download'),
          backgroundColor: Colors.orange,
        ),
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
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        final bytes = base64.decode(base64Content);

        // Show preview dialog for images and PDFs
        if (mounted) {
          _showDocumentPreview(bytes, contentType, name);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download: $e'),
            backgroundColor: Colors.red,
          ),
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
              // Header
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
              // Preview content
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
              // Action buttons
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

            // Invoice Validations
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
    List<Map<String, dynamic>> allRows = [];

    if (validationDetailsJson != null && validationDetailsJson.isNotEmpty) {
      try {
        validationDetails =
            jsonDecode(validationDetailsJson) as Map<String, dynamic>;
        if (validationDetails != null) {
          allRows = _extractAllValidationRows(validationDetails);
        }
      } catch (e) {
        debugPrint('Error parsing invoice validation details: $e');
      }
    }

    final passedCount = allRows.where((r) => r['passed'] == true).length;
    final totalCount = allRows.length;

    return _buildValidationCard(
      title: 'Invoice Validations',
      fileName: fileName,
      passedCount: passedCount,
      totalCount: totalCount,
      rows: allRows,
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
    final failureReason = photo['failureReason'] as String?;

    Map<String, dynamic>? validationDetails;
    List<Map<String, dynamic>> allRows = [];

    if (validationDetailsJson != null && validationDetailsJson.isNotEmpty && validationDetailsJson != '{}') {
      try {
        validationDetails =
            jsonDecode(validationDetailsJson) as Map<String, dynamic>;
        if (validationDetails != null) {
          allRows = _extractAllValidationRows(validationDetails);
        }
      } catch (e) {
        debugPrint('Error parsing photo validation details: $e');
      }
    }

    // Fallback: if no rows extracted from validationDetailsJson, parse failureReason
    if (allRows.isEmpty && failureReason != null && failureReason.isNotEmpty) {
      final reasons = failureReason.split('; ');
      for (final reason in reasons) {
        allRows.add({'label': reason.trim(), 'passed': false, 'message': reason.trim()});
      }
    }

    final passedCount = allRows.where((r) => r['passed'] == true).length;
    final totalCount = allRows.length;

    return _buildValidationCard(
      title: 'Photo Validations',
      fileName: fileName,
      passedCount: passedCount,
      totalCount: totalCount,
      rows: allRows,
    );
  }

  /// Extracts all validation rows from ValidationDetailsJson into a unified list.
  /// Reads: fieldPresence, crossDocument, amountConsistency, lineItemMatching,
  /// vendorMatching, completeness, and proactiveRules — deduplicating by label.
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
    final proactiveRules = details['proactiveRules'] as List<dynamic>?;
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
        // Invoice/CostSummary/Activity: each missing field is a row
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
              'Present in $photosWithDate/$totalPhotos photos');
          addRow('Location in Photos', photosWithLocation == totalPhotos,
              'Present in $photosWithLocation/$totalPhotos photos');
          addRow('Blue T-shirt Detection', photosWithBlueTshirt > 0,
              'Detected in $photosWithBlueTshirt/$totalPhotos photos');
          addRow('Bajaj Vehicle Detection', photosWithVehicle > 0,
              'Detected in $photosWithVehicle/$totalPhotos photos');
          addRow('Face Detection', photosWithFace > 0,
              'Detected in $photosWithFace/$totalPhotos photos');
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
        'gstPercentageValid': ('GST Percentage', 'GST percentage is valid', 'GST percentage is invalid'),
      };
      for (final entry in checkMap.entries) {
        final val = crossDocument[entry.key];
        if (val != null && val is bool) {
          addRow(entry.value.$1, val, val ? entry.value.$2 : entry.value.$3);
        }
      }
      // Cross-document issues as separate rows
      final issues = crossDocument['issues'] as List<dynamic>? ?? [];
      for (final issue in issues) {
        addRow(issue.toString(), false, issue.toString());
      }
    }

    // 4. Amount consistency (Invoice)
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

    // 5. Line item matching (Invoice)
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

    // 6. Vendor matching (Invoice)
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

    // 7. Completeness (CostSummary)
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

  /// Converts a proactive rule code like "INV_INVOICE_NUMBER_PRESENT" to a readable label.
  String _ruleCodeToLabel(String ruleCode) {
    const labelMap = {
      'INV_INVOICE_NUMBER_PRESENT': 'Invoice Number',
      'INV_DATE_PRESENT': 'Invoice Date',
      'INV_AMOUNT_PRESENT': 'Invoice Amount',
      'INV_GST_NUMBER_PRESENT': 'GST Number',
      'INV_GST_PERCENT_PRESENT': 'GST Percentage',
      'INV_HSN_SAC_PRESENT': 'HSN/SAC Code',
      'INV_VENDOR_CODE_PRESENT': 'Vendor Code',
      'INV_PO_NUMBER_MATCH': 'PO Number Match',
      'INV_AMOUNT_VS_PO_BALANCE': 'Amount vs PO Balance',
      'AS_DEALER_LOCATION_PRESENT': 'Dealer/Location',
      'AS_DAYS_MATCH_COST_SUMMARY': 'Days Match (Cost Summary)',
      'AS_DAYS_MATCH_TEAM_DETAILS': 'Days Match (Team Details)',
      'CS_PLACE_OF_SUPPLY_PRESENT': 'Place of Supply',
      'CS_TOTAL_DAYS_PRESENT': 'Total Days',
      'CS_TOTAL_VS_INVOICE': 'Total vs Invoice',
      'CS_ELEMENT_COST_VS_RATES': 'Element Cost vs Rates',
    };
    return labelMap[ruleCode] ??
        ruleCode
            .replaceAll('_', ' ')
            .replaceFirst(RegExp(r'^(INV|AS|CS|PO)\s'), '')
            .trim();
  }

  /// Reusable validation card with header and table rows.
  Widget _buildValidationCard({
    required String title,
    required String fileName,
    required int passedCount,
    required int totalCount,
    required List<Map<String, dynamic>> rows,
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
                if (totalCount > 0)
                  RichText(
                    text: TextSpan(children: [
                      TextSpan(
                        text: '$passedCount/$totalCount ',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11),
                      ),
                      TextSpan(
                        text: 'Passed',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: const Color(0xFF16A34A),
                            fontWeight: FontWeight.w600,
                            fontSize: 11),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
          // Table
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
                child: Text('WHAT WAS CHECKED',
                    style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontSize: 11)),
              ),
              SizedBox(
                width: 80,
                child: Text('RESULT',
                    style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontSize: 11),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Text('WHAT WAS FOUND',
                    style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontSize: 11)),
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

  Widget _buildSingleValidationCard({
    required String title,
    String? fileName,
    required Map<String, dynamic> validation,
  }) {
    final validationDetailsJson =
        validation['validationDetailsJson'] as String?;

    List<Map<String, dynamic>> allRows = [];

    if (validationDetailsJson != null && validationDetailsJson.isNotEmpty) {
      try {
        final validationDetails =
            jsonDecode(validationDetailsJson) as Map<String, dynamic>;
        allRows = _extractAllValidationRows(validationDetails);
      } catch (e) {
        debugPrint('Error parsing validation details for $title: $e');
      }
    }

    final passedCount = allRows.where((r) => r['passed'] == true).length;
    final totalCount = allRows.length;

    return _buildValidationCard(
      title: title,
      fileName: fileName ?? '',
      passedCount: passedCount,
      totalCount: totalCount,
      rows: allRows,
    );
  }

}
