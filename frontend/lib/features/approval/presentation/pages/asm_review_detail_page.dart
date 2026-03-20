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
        final photoValidations =
            submissionData['photoValidations'] as List<dynamic>? ?? [];
        final costSummaryValidation =
            submissionData['costSummaryValidation'] as Map<String, dynamic>? ??
                {};
        final activityValidation =
            submissionData['activityValidation'] as Map<String, dynamic>? ?? {};
        final enquiryValidation =
            submissionData['enquiryValidation'] as Map<String, dynamic>? ?? {};

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

    if (normalizedState == 'pendingapproval' ||
        normalizedState == 'pendingchapproval') {
      backgroundColor = const Color(0xFFDEEAFF);
      textColor = const Color(0xFF0066FF);
      displayText = 'Pending';
    } else if (normalizedState == 'asmapproved' ||
        normalizedState == 'pendinghqapproval') {
      backgroundColor = const Color(0xFFDEEAFF);
      textColor = const Color(0xFF0066FF);
      displayText = 'Pending with RA';
    } else if (normalizedState == 'approved') {
      backgroundColor = const Color(0xFFD1FAE5);
      textColor = const Color(0xFF10B981);
      displayText = 'Approved';
    } else if (normalizedState == 'rejectedbyhq' ||
        normalizedState == 'rejectedbyra') {
      backgroundColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFEF4444);
      displayText = 'Rejected by RA';
    } else if (normalizedState == 'rejectedbyasm' ||
        normalizedState == 'rejected') {
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
    return state == 'pendingapproval' || state == 'pendingasmapproval';
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
    final allPassed = invoice['allPassed'] ?? false;
    final failureReason = invoice['failureReason'];
    final validationDetailsJson = invoice['validationDetailsJson'] as String?;

    Map<String, dynamic>? validationDetails;
    int passedCount = 0;
    int totalCount = 0;

    if (validationDetailsJson != null && validationDetailsJson.isNotEmpty) {
      try {
        validationDetails =
            jsonDecode(validationDetailsJson) as Map<String, dynamic>;

        // Count passed and total validations
        if (validationDetails != null) {
          // Count proactive validations
          if (validationDetails['proactive'] != null) {
            final proactive = validationDetails['proactive'] as List<dynamic>;
            totalCount += proactive.length;
            passedCount += proactive.where((v) => v['passed'] == true).length;
          }

          // Count reactive validations
          if (validationDetails['reactive'] != null) {
            final reactive = validationDetails['reactive'] as List<dynamic>;
            totalCount += reactive.length;
            passedCount += reactive.where((v) => v['passed'] == true).length;
          }

          // Count checks
          if (validationDetails['checks'] != null) {
            final checks = validationDetails['checks'] as List<dynamic>;
            totalCount += checks.length;
            passedCount += checks.where((v) => v['passed'] == true).length;
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 240, 237, 237),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
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
    final allPassed = photo['allPassed'] ?? false;
    final failureReason = photo['failureReason'];
    final validationDetailsJson = photo['validationDetailsJson'] as String?;

    Map<String, dynamic>? validationDetails;
    int passedCount = 0;
    int totalCount = 0;

    if (validationDetailsJson != null && validationDetailsJson.isNotEmpty) {
      try {
        validationDetails =
            jsonDecode(validationDetailsJson) as Map<String, dynamic>;

        // Count passed and total validations
        if (validationDetails != null) {
          // Count required items (for photos)
          if (validationDetails['requiredItems'] != null) {
            final items = validationDetails['requiredItems'] as List<dynamic>;
            totalCount += items.length;
            passedCount += items.where((v) => v['passed'] == true).length;
          }

          // Count checks
          if (validationDetails['checks'] != null) {
            final checks = validationDetails['checks'] as List<dynamic>;
            totalCount += checks.length;
            passedCount += checks.where((v) => v['passed'] == true).length;
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

    Map<String, dynamic>? validationDetails;
    int passedCount = 0;
    int totalCount = 0;

    if (validationDetailsJson != null && validationDetailsJson.isNotEmpty) {
      try {
        validationDetails =
            jsonDecode(validationDetailsJson) as Map<String, dynamic>;

        // Count passed and total validations
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
      // Add specific validation checks for cost summary
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
}
