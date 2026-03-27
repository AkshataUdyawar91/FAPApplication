import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../../../../core/constants/api_constants.dart';
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
import '../../../../core/widgets/photo_thumbnail_gallery.dart';
import '../../../../core/router/app_router.dart';
import '../../data/models/invoice_summary_data.dart';
import '../../data/models/invoice_document_row.dart';
import '../utils/submission_data_transformer.dart';
import '../widgets/invoice_summary_section.dart';
import '../widgets/campaign_details_table.dart';
import '../widgets/ai_analysis_section.dart';
import '../../data/models/campaign_detail_row.dart';
import '../../../submission/presentation/widgets/document_preview_screen.dart';

class ASMReviewDetailPage extends ConsumerStatefulWidget {
  final String submissionId;
  final String token;
  final String userName;
  final String? poNumber;

  const ASMReviewDetailPage({
    super.key,
    required this.submissionId,
    required this.token,
    required this.userName,
    this.poNumber,
  });

  @override
  ConsumerState<ASMReviewDetailPage> createState() =>
      _ASMReviewDetailPageState();
}

class _ASMReviewDetailPageState extends ConsumerState<ASMReviewDetailPage> {
  final _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      // Disable caching
      headers: {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      },
    ),
  )..interceptors.add(PrettyDioLogger());
  // Separate Dio for view/download — no response body logging (base64 floods console)
  final _dioSilent = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      headers: {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      },
    ),
  )..interceptors.add(PrettyDioLogger(responseBody: false));
  final _commentsController = TextEditingController();
  late ScrollController _scrollController;

  bool _isLoading = true;
  Map<String, dynamic>? _submission;
  bool _isProcessing = false;
  bool _isChatOpen = false;
  bool _isSidebarCollapsed = true;

  // Transformed data for new layout
  InvoiceSummaryData? _invoiceSummary;
  List<CampaignDetailRow> _campaignDetails = [];

  // Validation data from submission response
  List<dynamic> _invoiceValidations = [];
  List<dynamic> _photoValidations = [];
  Map<String, dynamic> _costSummaryValidation = {};
  Map<String, dynamic> _activityValidation = {};
  Map<String, dynamic> _enquiryValidation = {};

  // Blob URLs for Cost Summary, Activity Summary, and Enquiry (fallback when documentId unavailable)
  String? _costSummaryBlobUrl;
  String? _activitySummaryBlobUrl;
  String? _enquiryBlobUrl;

  // PO Balance state
  bool _isLoadingPoBalance = false;
  Map<String, dynamic>? _poBalanceResult;
  String? _poBalanceError;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadSubmissionDetails();
  }

  @override
  void dispose() {
    _commentsController.dispose();
    _scrollController.dispose();
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
              options:
                  Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
            );
            if (valResponse.statusCode == 200 && valResponse.data != null) {
              final docs =
                  valResponse.data['documents'] as List<dynamic>? ?? [];
              final photoDocs =
                  docs.where((d) => d['documentType'] == 'TeamPhoto').toList();
              if (photoDocs.isNotEmpty) {
                photoValidations = photoDocs;
              }
            }
          } catch (e) {
            debugPrint('Fallback photo validation fetch failed: $e');
          }
        }

        // Extract blob URLs for Cost Summary and Activity Summary from campaigns
        String? costSummaryBlobUrl;
        String? activitySummaryBlobUrl;
        final campaignsList =
            submissionData['campaigns'] as List<dynamic>? ?? [];
        if (campaignsList.isNotEmpty) {
          final firstCampaign = campaignsList[0] as Map<String, dynamic>;
          costSummaryBlobUrl =
              firstCampaign['costSummaryBlobUrl']?.toString() ??
                  firstCampaign['costSummaryUrl']?.toString();
          activitySummaryBlobUrl =
              firstCampaign['activitySummaryBlobUrl']?.toString() ??
                  firstCampaign['activitySummaryUrl']?.toString() ??
                  firstCampaign['activityBlobUrl']?.toString();
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
          _campaignDetails = allCampaignDetails;
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
          IconButton(
            onPressed: _scrollToComments,
            icon: const Icon(Icons.comment, color: Colors.white, size: 22),
            tooltip: 'View comments',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  void _scrollToComments() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
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
                  userRole: 'Circle Head',
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
                        userRole: 'Circle Head',
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
                                  controller: _scrollController,
                                  padding: const EdgeInsets.all(24),
                                  child: isMobile
                                    // Mobile: single column with timeline at bottom
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildHeaderSection(),
                                          const SizedBox(height: 24),
                                          if (_invoiceSummary != null)
                                            InvoiceSummarySection(data: _invoiceSummary!),
                                          const SizedBox(height: 24),
                                          AiAnalysisSection(submission: _submission!),
                                          const SizedBox(height: 24),
                                          Visibility(
                                            visible: false,
                                            child: CampaignDetailsTable(
                                              campaignDetails: _campaignDetails,
                                              onPhotoTap: (detail) {
                                                if (detail.downloadPath != null && detail.downloadPath!.isNotEmpty) {
                                                  _downloadHierarchicalDocument(detail.downloadPath!, detail.documentName);
                                                } else if (detail.documentId != null && detail.documentId!.isNotEmpty) {
                                                  _downloadDocument(detail.documentId, detail.documentName);
                                                } else {
                                                  _downloadDocumentByUrl(detail.blobUrl, detail.documentName);
                                                }
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                          _buildValidationReportSection(),
                                          ..._buildPhotoGallerySection(),
                                          const SizedBox(height: 24),
                                          _buildApprovalTimeline(),
                                          const SizedBox(height: 80),
                                        ],
                                      )
                                    // Desktop/Tablet: header full-width, then 3/4 body + 1/4 sidebar aligned at same top
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Full-width header with approve/reject actions
                                          _buildHeaderSection(),
                                          const SizedBox(height: 24),
                                          // Side-by-side: body content + approval flow
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    if (_invoiceSummary != null)
                                                      InvoiceSummarySection(data: _invoiceSummary!),
                                                    const SizedBox(height: 24),
                                                    AiAnalysisSection(submission: _submission!),
                                                    const SizedBox(height: 24),
                                                    Visibility(
                                                      visible: false,
                                                      child: CampaignDetailsTable(
                                                        campaignDetails: _campaignDetails,
                                                        onPhotoTap: (detail) {
                                                          if (detail.downloadPath != null && detail.downloadPath!.isNotEmpty) {
                                                            _downloadHierarchicalDocument(detail.downloadPath!, detail.documentName);
                                                          } else if (detail.documentId != null && detail.documentId!.isNotEmpty) {
                                                            _downloadDocument(detail.documentId, detail.documentName);
                                                          } else {
                                                            _downloadDocumentByUrl(detail.blobUrl, detail.documentName);
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                    _buildValidationReportSection(),
                                                    ..._buildPhotoGallerySection(),
                                                    const SizedBox(height: 80),
                                                  ],
                                                ),
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
    String reqNumber = _submission!['submissionNumber']?.toString() ??
        'REQ-${widget.submissionId.substring(0, 8).toUpperCase()}';

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 500;

            if (isMobile) {
              return _buildMobileHeader(
                invoiceNumber: invoiceNumber,
                agencyName: agencyName,
                reqNumber: reqNumber,
                submittedDate: submittedDate,
              );
            }

            return _buildDesktopHeader(
              invoiceNumber: invoiceNumber,
              agencyName: agencyName,
              reqNumber: reqNumber,
              submittedDate: submittedDate,
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileHeader({
    required String invoiceNumber,
    required String agencyName,
    required String reqNumber,
    required dynamic submittedDate,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back button + title
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to review list',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                invoiceNumber.isNotEmpty && agencyName.isNotEmpty
                    ? '$invoiceNumber - $agencyName'
                    : invoiceNumber.isNotEmpty
                        ? invoiceNumber
                        : agencyName.isNotEmpty
                            ? agencyName
                            : 'Submission Details',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Metadata
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reqNumber,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDisplayDate(submittedDate),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // PO Balance — full width
        _buildPoBalanceSection(),
        // Action buttons
        if (_isSubmissionActionable()) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: _isProcessing ? null : _showRejectDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text('Reject'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _approveSubmission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
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
                      : const Text(
                          'Approve Request',
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'Comments (Optional)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
      ],
    );
  }

  Widget _buildDesktopHeader({
    required String invoiceNumber,
    required String agencyName,
    required String reqNumber,
    required dynamic submittedDate,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column: back button + title + action buttons
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button and title row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                              invoiceNumber.isNotEmpty &&
                                      agencyName.isNotEmpty
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
                    ],
                  ),
                  // Action buttons — only for actionable states
                  if (_isSubmissionActionable()) ...[
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton(
                          onPressed:
                              _isProcessing ? null : _showRejectDialog,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side:
                                const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                          child: const Text('Reject'),
                        ),
                        ElevatedButton(
                          onPressed:
                              _isProcessing ? null : _approveSubmission,
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
                  ],
                ],
              ),
            ),
            const SizedBox(width: 24),
            // Right column: PO Balance
            _buildPoBalanceSection(),
          ],
        ),
        // Comments — full width below both columns
        if (_isSubmissionActionable()) ...[
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
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
      ],
    );
  }

  Widget _buildPoBalanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 40,
          child: ElevatedButton.icon(
            onPressed: _isLoadingPoBalance ? null : _fetchPoBalance,
            icon: _isLoadingPoBalance
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.account_balance_wallet_outlined, size: 16),
            label:
                Text(_isLoadingPoBalance ? 'Checking...' : 'Check PO Balance'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003087),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (_poBalanceResult != null) ...[
          const SizedBox(height: 6),
          _buildPoBalanceResult(_poBalanceResult!),
        ],
        if (_poBalanceError != null) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 14, color: Color(0xFFDC2626)),
              const SizedBox(width: 4),
              Text(
                _poBalanceError!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPoBalanceResult(Map<String, dynamic> result) {
    final balance = result['balance'];
    final currency = result['currency']?.toString() ?? 'INR';

    final balanceValue = balance is num
        ? balance.toDouble()
        : double.tryParse(balance?.toString() ?? '') ?? 0.0;
    final isPositive = balanceValue >= 0;
    final balanceColor =
        isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final formattedBalance =
        '${isPositive ? '' : '-'}$currency ${balanceValue.abs().toStringAsFixed(2)}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Balance: ',
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        Text(
          formattedBalance,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: balanceColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String state) {
    final normalizedState = state.toLowerCase();

    Color backgroundColor;
    Color textColor;
    String displayText;

    if (normalizedState == 'pendingch' ||
        normalizedState == 'pendingapproval' ||
        normalizedState == 'pendingchapproval') {
      backgroundColor = const Color(0xFFDEEAFF);
      textColor = const Color(0xFF0066FF);
      displayText = 'Pending';
    } else if (normalizedState == 'pendingra' ||
        normalizedState == 'asmapproved' ||
        normalizedState == 'pendinghqapproval') {
      backgroundColor = const Color(0xFFDEEAFF);
      textColor = const Color(0xFF0066FF);
      displayText = 'Pending with RA';
    } else if (normalizedState == 'approved') {
      backgroundColor = const Color(0xFFD1FAE5);
      textColor = const Color(0xFF10B981);
      displayText = 'Approved';
    } else if (normalizedState == 'rarejected' ||
        normalizedState == 'rejectedbyhq' ||
        normalizedState == 'rejectedbyra') {
      backgroundColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFEF4444);
      displayText = 'Rejected by RA';
    } else if (normalizedState == 'chrejected' ||
        normalizedState == 'rejectedbyasm' ||
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
    return state == 'pendingch' ||
        state == 'pendingapproval' ||
        state == 'pendingchapproval' ||
        state == 'rarejected';
  }

  /// Extracts the PO number from the submission's documents array.
  String? _extractPoNumber() {
    // Fast path: use the PO number passed directly from the dashboard list
    if (widget.poNumber != null && widget.poNumber!.isNotEmpty) {
      return widget.poNumber;
    }
    final documents = _submission?['documents'] as List? ?? [];
    for (final doc in documents) {
      final type = doc['type']?.toString() ?? '';
      if (type == 'PO') {
        final extractedData = doc['extractedData'];
        Map<String, dynamic>? data;
        if (extractedData is String && extractedData.isNotEmpty) {
          try {
            data = jsonDecode(extractedData) as Map<String, dynamic>?;
          } catch (_) {}
        } else if (extractedData is Map) {
          data = Map<String, dynamic>.from(extractedData);
        }
        if (data != null) {
          final poNum = data['PONumber'] ??
              data['poNumber'] ??
              data['PO_Number'] ??
              data['po_number'];
          if (poNum != null && poNum.toString().isNotEmpty)
            return poNum.toString();
        }
        final poNum =
            doc['poNumber']?.toString() ?? doc['PONumber']?.toString();
        if (poNum != null && poNum.isNotEmpty) return poNum;
      }
    }
    return null;
  }

  Future<void> _fetchPoBalance() async {
    final poNum = _extractPoNumber();
    if (poNum == null || poNum.isEmpty) {
      setState(() {
        _poBalanceError = 'PO number not found in this submission.';
        _poBalanceResult = null;
      });
      return;
    }

    setState(() {
      _isLoadingPoBalance = true;
      _poBalanceError = null;
      _poBalanceResult = null;
    });

    try {
      final response = await _dio.get(
        '/po-balance/$poNum',
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _poBalanceResult = response.data as Map<String, dynamic>;
          _isLoadingPoBalance = false;
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Failed to fetch PO balance.';
        if (e is DioException && e.response != null) {
          errorMsg = e.response?.data?['message']?.toString() ?? errorMsg;
        }
        setState(() {
          _poBalanceError = errorMsg;
          _isLoadingPoBalance = false;
        });
      }
    }
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

  /// Opens a blob URL in a new browser tab for viewing.
  void _openBlobUrl(String blobUrl, String filename) {
    if (blobUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Document URL not available'),
            backgroundColor: Colors.orange),
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
        const SnackBar(
            content: Text('Document URL not available'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = blobUrl;
    anchor.download = filename;
    anchor.click();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Downloading $filename...'),
            backgroundColor: AppColors.approvedText,
            duration: const Duration(seconds: 2)),
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
        final contentType = response.data['contentType']?.toString() ??
            'application/octet-stream';
        final name = response.data['filename']?.toString() ?? filename;
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
        
        // Get validation data for this document
        final validation = _getValidationForDocument(documentId);
        final isPassed = validation?['allValidationsPassed'] ?? validation?['allPassed'] ?? true;
        final failureReason = validation?['failureReason']?.toString();
        final photoDate = _getPhotoDateForDocument(documentId)
            ?? validation?['validatedAt']?.toString();
        final dateStr = _formatPreviewDate(photoDate);
        
        // Create blob URL from base64
        final bytes = base64.decode(base64Content);
        final blob = web.Blob(
          [bytes.toJS].toJS,
          web.BlobPropertyBag(type: contentType),
        );
        final blobUrl = web.URL.createObjectURL(blob);
        
        // Create preview data
        final previewData = DocumentPreviewData(
          filename: name,
          imageUrl: blobUrl,
          isPassed: isPassed,
          failureReason: failureReason,
          date: dateStr,
        );
        
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => DocumentPreviewScreen(
              documents: [previewData],
              initialIndex: 0,
              onClose: () {
                Navigator.pop(context);
                web.URL.revokeObjectURL(blobUrl);
              },
              onDownload: () {
                final anchor = web.document.createElement('a')
                    as web.HTMLAnchorElement;
                anchor.href = blobUrl;
                anchor.download = name;
                anchor.click();
              },
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load document: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Get validation data for a specific document.
  /// For photos, also checks per-photo validation from the gallery data
  /// since photo validations are often aggregate (documentId = packageId).
  Map<String, dynamic>? _getValidationForDocument(String documentId) {
    // Check photo validations (direct match)
    for (final v in _photoValidations) {
      final vMap = v as Map<String, dynamic>;
      if (vMap['documentId']?.toString() == documentId) {
        return vMap;
      }
    }
    
    // Check invoice validations
    for (final v in _invoiceValidations) {
      final vMap = v as Map<String, dynamic>;
      if (vMap['documentId']?.toString() == documentId) {
        return vMap;
      }
    }
    
    // Check cost summary validation
    if (_costSummaryValidation?['documentId']?.toString() == documentId) {
      return _costSummaryValidation;
    }
    
    // Check activity validation
    if (_activityValidation?['documentId']?.toString() == documentId) {
      return _activityValidation;
    }

    // Fallback for photos: check per-photo status from gallery validation logic
    final galleryPhotos = _collectPhotosWithValidation();
    for (final item in galleryPhotos) {
      if (item.documentId == documentId) {
        return {
          'allValidationsPassed': !item.hasError,
          'failureReason': item.hasError ? 'Photo validation failed' : null,
        };
      }
    }
    
    return null;
  }

  /// Gets the photo date (EXIF timestamp or overlay date) for a document by searching campaigns.
  String? _getPhotoDateForDocument(String documentId) {
    final campaigns = _submission?['campaigns'] as List? ?? [];
    for (final campaign in campaigns) {
      final photos = (campaign as Map<String, dynamic>)['photos'] as List? ?? [];
      for (final photo in photos) {
        final photoMap = photo as Map<String, dynamic>;
        final id = photoMap['id']?.toString() ?? '';
        if (id == documentId) {
          return photoMap['photoTimestamp']?.toString()
              ?? photoMap['photoDateOverlay']?.toString();
        }
      }
    }
    return null;
  }

  /// Formats a UTC date string for the document preview panel.
  String? _formatPreviewDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _downloadDocumentDirect(
      String? documentId, String? filename) async {
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
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
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
            SnackBar(
                content: Text('Downloading $name...'),
                backgroundColor: AppColors.approvedText,
                duration: const Duration(seconds: 2)),
          );
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

  /// Checks if a validation entry has any warning rules that did not pass.
  bool _hasWarningRules(Map<String, dynamic> validation) {
    try {
      final detailsJson = validation['validationDetailsJson']?.toString() ?? '';
      if (detailsJson.isEmpty) return false;
      final details = json.decode(detailsJson);
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

    final isProcessing = state == 'draft' || state == 'uploaded' ||
        state == 'extracting' || state == 'validating';

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
          isPending = true;
          hasError = false;
          hasWarning = false;
        } else {
          final validation = validationByDocId[docId];
          if (validation != null) {
            isPending = false;
            final allPassed = validation['allPassed'] == true ||
                validation['allValidationsPassed'] == true;
            final failureReason =
                validation['failureReason']?.toString() ?? '';
            hasError = !allPassed || failureReason.isNotEmpty;
            hasWarning = !hasError && _hasWarningRules(validation);
          } else if (aggregateValidation != null) {
            // No per-photo validation — don't inherit aggregate allPassed
            // (it includes cross-document checks like "No. of Days" unrelated to individual photo quality)
            isPending = false;
            hasError = false;
            hasWarning = false;
          } else {
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

  Widget _buildApprovalTimeline() {
    final state = _submission!['state']?.toString().toLowerCase() ?? '';
    final createdAt = _submission!['createdAt'];
    final asmReviewedAt = _submission!['asmReviewedAt'];
    final asmReviewNotes = _submission!['asmReviewNotes']?.toString();
    final hqReviewedAt = _submission!['hqReviewedAt'];
    final hqReviewNotes = _submission!['hqReviewNotes']?.toString();

    // Also read the full approvalHistory array if available
    final approvalHistory = _submission!['approvalHistory'] as List<dynamic>? ?? [];

    // Determine ASM status
    String asmStatus = 'pending';
    if (state.contains('chrejected') || state.contains('rejectedbyasm')) {
      asmStatus = 'rejected';
    } else if (state.contains('chapproved') || state.contains('approved') ||
        state.contains('rapending') || state.contains('pendingra') ||
        state.contains('rarejected') || state.contains('rejectedbyhq')) {
      asmStatus = 'approved';
    } else if (asmReviewedAt != null) {
      asmStatus = 'approved';
    }

    // Determine HQ/RA status
    String hqStatus = 'pending';
    if (state == 'approved' || state == 'raapproved') {
      hqStatus = 'approved';
    } else if (state.contains('rarejected') || state.contains('rejectedbyhq')) {
      hqStatus = 'rejected';
    } else if (hqReviewedAt != null) {
      hqStatus = 'approved';
    }

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
            Row(
              children: [
                const Icon(Icons.timeline, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                const Text('Approval Flow', style: AppTextStyles.h3),
              ],
            ),
            const SizedBox(height: 20),
            _buildTimelineStep(
              icon: Icons.upload_file,
              color: const Color(0xFF3B82F6),
              title: 'Submitted',
              date: _formatDisplayDate(createdAt),
              comment: null,
              isCompleted: true,
              isLast: false,
            ),
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
              date: asmReviewedAt != null ? _formatDisplayDate(asmReviewedAt) : null,
              comment: asmReviewNotes,
              isCompleted: asmStatus != 'pending',
              isLast: false,
            ),
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
                  ? 'Approved by RA'
                  : hqStatus == 'rejected'
                      ? 'Rejected by RA'
                      : 'Pending RA Review',
              date: hqReviewedAt != null ? _formatDisplayDate(hqReviewedAt) : null,
              comment: hqReviewNotes,
              isCompleted: hqStatus != 'pending',
              isLast: true,
            ),
            // Show full approval history if available
            if (approvalHistory.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text('History', style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              ...approvalHistory.map((h) {
                final entry = h as Map<String, dynamic>;
                final action = entry['action']?.toString() ?? '';
                final role = entry['approverRole']?.toString() ?? '';
                final name = entry['approverName']?.toString() ?? role;
                final comments = entry['comments']?.toString();
                final date = entry['actionDate'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        action.toLowerCase().contains('approved')
                            ? Icons.check_circle_outline
                            : action.toLowerCase().contains('rejected')
                                ? Icons.highlight_off
                                : Icons.info_outline,
                        size: 16,
                        color: action.toLowerCase().contains('approved')
                            ? const Color(0xFF10B981)
                            : action.toLowerCase().contains('rejected')
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$action by $name',
                              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (date != null)
                              Text(
                                _formatDisplayDate(date),
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontSize: 11, color: AppColors.textSecondary),
                              ),
                            if (comments != null && comments.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: Text(
                                  comments,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: const Color(0xFF4B5563), height: 1.4),
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
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? color.withValues(alpha: 0.3) : const Color(0xFFE5E7EB),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? AppColors.textPrimary : AppColors.textSecondary,
                  )),
                  if (date != null && date.isNotEmpty)
                    Text(date, style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary, fontSize: 11)),
                  if (comment != null && comment.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(6),
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
    final docId = invoice['documentId']?.toString() ??
        invoice['id']?.toString() ??
        _getDocumentIdByType('Invoice');
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

    // Filter to only the 9 invoice rows per spec
    allRows = _filterInvoiceRows(allRows);

    final passedCount = allRows.where((r) => r['passed'] == true).length;
    final totalCount = allRows.length;

    return _buildValidationCard(
      title: 'Invoice Validations',
      fileName: fileName,
      passedCount: passedCount,
      totalCount: totalCount,
      rows: allRows,
      documentId: docId,
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

    Map<String, dynamic>? validationDetails;
    List<Map<String, dynamic>> allRows = [];

    if (validationDetailsJson != null &&
        validationDetailsJson.isNotEmpty &&
        validationDetailsJson != '{}') {
      try {
        validationDetails =
            jsonDecode(validationDetailsJson) as Map<String, dynamic>;
        if (validationDetails != null) {
          allRows = _extractPhotoValidationRows(validationDetails);
        }
      } catch (e) {
        debugPrint('Error parsing photo validation details: $e');
      }
    }

    // Fallback: if no rows extracted from validationDetailsJson, parse failureReason
    if (allRows.isEmpty && failureReason != null && failureReason.isNotEmpty) {
      final reasons = failureReason.split('; ');
      for (final reason in reasons) {
        allRows.add({
          'label': reason.trim(),
          'passed': false,
          'message': reason.trim()
        });
      }
    }

    return _buildValidationCard(
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
                ? 'Unique photo days ($uniquePhotoDays) matches Activity Summary days ($activityDays)'
                : 'Unique photo days ($uniquePhotoDays) does not match Activity Summary days ($activityDays)');
      }
    }

    // Blue T-shirt & Branded 3W
    if (totalPhotos != null && totalPhotos > 0) {
      final photosWithBlueTshirt = fieldPresence?['photosWithBlueTshirt'] ?? 0;
      addRow('Promoter wearning blue T-shirt', photosWithBlueTshirt > 0,
          '$photosWithBlueTshirt/$totalPhotos Photos have promoters wearing blue T-shirt');

      final photosWithVehicle = fieldPresence?['photosWithVehicle'] ?? 0;
      addRow('Branded 3 wheeler', photosWithVehicle > 0,
          '$photosWithVehicle/$totalPhotos Photos have branded 3 wheelers');
    }

    return rows;
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
    // Backend stores rules under 'proactiveRules' (ValidationAgent merge) or 'rules' (AssistantController)
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
        'totalCostValid': (
          'Total Cost Validation',
          'Total cost matches invoice',
          'Total cost does not match invoice'
        ),
        'elementCostsValid': (
          'Element Costs Validation',
          'Element costs are valid',
          'Element costs are invalid'
        ),
        'fixedCostsValid': (
          'Fixed Costs Validation',
          'Fixed costs are valid',
          'Fixed costs are invalid'
        ),
        'variableCostsValid': (
          'Variable Costs Validation',
          'Variable costs are valid',
          'Variable costs are invalid'
        ),
        'numberOfDaysMatches': (
          'Number of Days Match',
          'Days match between documents',
          'Days mismatch between documents'
        ),
        'photoCountMatchesManDays': (
          'Photo Count vs Man Days',
          'Photo count matches man days',
          'Photo count does not match man days'
        ),
        'manDaysWithinCostSummaryDays': (
          'Man Days vs Cost Summary Days',
          'Man days within cost summary days',
          'Man days exceed cost summary days'
        ),
        'agencyCodeMatches': (
          'Agency Code Match',
          'Agency code matches',
          'Agency code mismatch'
        ),
        'poNumberMatches': (
          'PO Number Match',
          'PO number matches',
          'PO number mismatch'
        ),
        'gstStateMatches': (
          'GST State Match',
          'GST state matches',
          'GST state mismatch'
        ),
        'hsnSacCodeValid': (
          'HSN/SAC Code',
          'HSN/SAC code is valid',
          'HSN/SAC code is invalid'
        ),
        'invoiceAmountValid': (
          'Invoice Amount',
          'Invoice amount is valid',
          'Invoice amount is invalid'
        ),
        // poBalanceValid intentionally excluded — use INV_AMOUNT_VS_PO_BALANCE from proactiveRules instead
        // to avoid showing a default "Pass" when the balance was never actually checked.
        'gstPercentageValid': (
          'GST Percentage',
          'GST percentage is valid',
          'GST percentage is invalid'
        ),
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
      final missing =
          lineItemMatching['missingItemCodes'] as List<dynamic>? ?? [];
      addRow(
        'Line Item Matching',
        allMatched == true,
        allMatched == true
            ? 'All PO line items found in invoice'
            : 'Missing ${missing.length} items: ${missing.join(", ")}',
      );
    }

    // 6. Vendor matching (Invoice)
    final vendorMatching = details['vendorMatching'] as Map<String, dynamic>?;
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
      // Web workflow rule codes (from BuildPerDocumentResults)
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
    String? documentId,
    String? blobUrl,
  }) {
    final resolvedDocId =
        (documentId != null && documentId.isNotEmpty) ? documentId : '';
    final resolvedBlobUrl = blobUrl ?? '';

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 400;

                final titleWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w600)),
                    if (fileName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(fileName,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                );

                final actionsWidget = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (totalCount > 0)
                      RichText(
                        text: TextSpan(children: [
                          TextSpan(
                            text: '${totalCount > 0 ? (passedCount * 100 ~/ totalCount) : 0}% ',
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
                    if (resolvedDocId.isNotEmpty ||
                        resolvedBlobUrl.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 28,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (resolvedDocId.isNotEmpty) {
                              _viewDocument(resolvedDocId, fileName);
                            } else {
                              _openBlobUrl(resolvedBlobUrl, fileName);
                            }
                          },
                          icon: const Icon(Icons.visibility, size: 13),
                          label: const Text('View',
                              style: TextStyle(fontSize: 11)),
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
                              _downloadDocumentDirect(resolvedDocId, fileName);
                            } else {
                              _downloadByBlobUrl(resolvedBlobUrl, fileName);
                            }
                          },
                          icon: const Icon(Icons.download, size: 13),
                          label: const Text('Download',
                              style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                    ],
                  ],
                );

                if (isMobile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleWidget,
                      const SizedBox(height: 8),
                      actionsWidget,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: titleWidget),
                    actionsWidget,
                  ],
                );
              },
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
                    color: const Color(0xFFE5E7EB), width: isLast ? 1 : 0.5),
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

  String _getDocumentIdByType(String type) {
    final documents = _submission?['documents'] as List<dynamic>? ?? [];
    final typeLower =
        type.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    for (final doc in documents) {
      final docType =
          (doc['type']?.toString() ?? doc['documentType']?.toString() ?? '')
              .toLowerCase()
              .replaceAll(' ', '')
              .replaceAll('_', '');
      if (docType == typeLower) {
        return doc['id']?.toString() ?? doc['documentId']?.toString() ?? '';
      }
    }
    return '';
  }

  /// Gets document ID for Cost Summary — checks documents array with multiple aliases,
  /// then falls back to campaigns array, then the validation object itself.
  String _getCostSummaryDocumentId() {
    for (final alias in [
      'CostSummary',
      'Cost Summary',
      'costsummary',
      'cost_summary'
    ]) {
      final id = _getDocumentIdByType(alias);
      if (id.isNotEmpty) return id;
    }
    if (_submission != null) {
      final campaigns = _submission!['campaigns'] as List? ?? [];
      for (final c in campaigns) {
        final id =
            (c as Map<String, dynamic>)['costSummaryDocumentId']?.toString() ??
                c['costSummaryId']?.toString() ??
                '';
        if (id.isNotEmpty) return id;
      }
    }
    return _costSummaryValidation['documentId']?.toString() ??
        _costSummaryValidation['id']?.toString() ??
        '';
  }

  /// Gets document ID for Activity Summary — checks documents array with multiple aliases,
  /// then falls back to campaigns array, then the validation object itself.
  String _getActivitySummaryDocumentId() {
    for (final alias in [
      'ActivitySummary',
      'Activity Summary',
      'activitysummary',
      'activity_summary',
      'Activity'
    ]) {
      final id = _getDocumentIdByType(alias);
      if (id.isNotEmpty) return id;
    }
    if (_submission != null) {
      final campaigns = _submission!['campaigns'] as List? ?? [];
      for (final c in campaigns) {
        final id = (c as Map<String, dynamic>)['activitySummaryDocumentId']
                ?.toString() ??
            c['activitySummaryId']?.toString() ??
            '';
        if (id.isNotEmpty) return id;
      }
    }
    return _activityValidation['documentId']?.toString() ??
        _activityValidation['id']?.toString() ??
        '';
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

  /// Gets document ID for Enquiry — checks documents array with multiple aliases,
  /// then falls back to campaigns array, then the validation object itself.
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
        : validation['documentId']?.toString() ??
            validation['id']?.toString() ??
            '';
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

    return _buildValidationCard(
      title: title,
      fileName: fileName ?? '',
      passedCount: passedCount,
      totalCount: totalCount,
      rows: hideRowsAndBadge ? [] : allRows,
      documentId: resolvedDocId.isNotEmpty ? resolvedDocId : null,
      blobUrl: resolvedBlobUrl.isNotEmpty ? resolvedBlobUrl : null,
    );
  }

  /// Filters cost summary validation rows to only the 8 key checks
  /// Finds the first source row matching any of the given aliases (case-insensitive).
  Map<String, dynamic>? _findRow(List<Map<String, dynamic>> rows, List<String> aliases) {
    for (final row in rows) {
      final label = (row['label'] as String? ?? '').toLowerCase();
      if (aliases.contains(label)) return row;
    }
    return null;
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
}
