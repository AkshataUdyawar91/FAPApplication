import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/invoice_summary_data.dart';
import '../../data/models/invoice_document_row.dart';
import '../../data/models/campaign_detail_row.dart';
import '../utils/submission_data_transformer.dart';
import '../widgets/invoice_summary_section.dart';
import '../widgets/invoice_documents_table.dart';
import '../widgets/campaign_details_table.dart';
import '../widgets/ai_analysis_section.dart';

class HQReviewDetailPage extends StatefulWidget {
  final String submissionId;
  final String token;
  final String userName;

  const HQReviewDetailPage({
    super.key,
    required this.submissionId,
    required this.token,
    required this.userName,
  });

  @override
  State<HQReviewDetailPage> createState() => _HQReviewDetailPageState();
}

class _HQReviewDetailPageState extends State<HQReviewDetailPage> {
  final _dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:5000/api',
    headers: {
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
      'Expires': '0',
    },
  ));
  final _commentsController = TextEditingController();

  bool _isLoading = true;
  Map<String, dynamic>? _submission;
  bool _isProcessing = false;

  // Transformed data for layout
  InvoiceSummaryData? _invoiceSummary;
  List<InvoiceDocumentRow> _invoiceDocuments = [];
  List<CampaignDetailRow> _campaignDetails = [];

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

        final invoiceSummary =
            SubmissionDataTransformer.extractInvoiceSummary(submissionData);
        final invoiceDocuments =
            SubmissionDataTransformer.transformToInvoiceDocuments(submissionData);
        final campaignDetails =
            SubmissionDataTransformer.transformToCampaignDetails(submissionData);

        setState(() {
          _submission = submissionData;
          _invoiceSummary = invoiceSummary;
          _invoiceDocuments = invoiceDocuments;
          _campaignDetails = campaignDetails;
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
        '/submissions/${widget.submissionId}/hq-approve',
        data: {'notes': _commentsController.text.trim()},
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('FAP approved successfully (Final Approval)'),
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
        '/submissions/${widget.submissionId}/hq-reject',
        data: {'reason': reason},
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('FAP rejected (sent back to ASM)'),
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
            const Text('Please provide a reason for rejection:'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _submission == null
              ? const Center(child: Text('Submission not found'))
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderSection(),
                            const SizedBox(height: 24),

                            // Invoice Summary Section
                            if (_invoiceSummary != null)
                              InvoiceSummarySection(data: _invoiceSummary!),
                            const SizedBox(height: 24),

                            // ASM Review Section (HQ-specific)
                            _buildASMReviewSection(),
                            const SizedBox(height: 24),

                            // Collapsible AI Analysis Section
                            AiAnalysisSection(submission: _submission!),
                            const SizedBox(height: 24),

                            // Invoice Documents Table
                            InvoiceDocumentsTable(
                              documents: _invoiceDocuments,
                              onDocumentTap: (doc) => _downloadDocument(
                                doc.documentId,
                                doc.documentName,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Campaign Details Table
                            CampaignDetailsTable(
                              campaignDetails: _campaignDetails,
                              onPhotoTap: (detail) => _downloadDocument(
                                detail.documentId,
                                detail.documentName,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildHeaderSection() {
    final documents = _submission!['documents'] as List? ?? [];
    String invoiceNumber = '';
    final reqNumber =
        'REQ-${widget.submissionId.substring(0, 8).toUpperCase()}';

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
        } catch (_) {}
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
                                    : 'HQ Final Review',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            reqNumber,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 16),
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
                ),
                _buildStatusBadge(state),
              ],
            ),
            const SizedBox(height: 20),

            // Action buttons — only for actionable states
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
                    child: const Text('Reject (Send to ASM)'),
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
                        : const Text('Final Approve'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Comments section
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

    if (normalizedState == 'pendinghqapproval') {
      backgroundColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFFD97706);
      displayText = 'Pending HQ Review';
    } else if (normalizedState == 'approved') {
      backgroundColor = const Color(0xFFD1FAE5);
      textColor = const Color(0xFF10B981);
      displayText = 'Approved';
    } else if (normalizedState == 'rejectedbyhq' || normalizedState == 'rejected') {
      backgroundColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFEF4444);
      displayText = normalizedState == 'rejectedbyhq' ? 'Rejected by HQ' : 'Rejected';
    } else if (normalizedState == 'pendingapproval') {
      backgroundColor = const Color(0xFFDEEAFF);
      textColor = const Color(0xFF0066FF);
      displayText = 'Pending ASM Review';
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

  Widget _buildASMReviewSection() {
    final asmReviewedAt = _submission!['asmReviewedAt'];
    final asmReviewNotes = _submission!['asmReviewNotes'];

    if (asmReviewedAt == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      color: const Color(0xFFEFF6FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFF10B981), size: 20),
                const SizedBox(width: 8),
                Text(
                  'ASM Review',
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Reviewed on: ${_formatDisplayDate(asmReviewedAt)}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (asmReviewNotes != null &&
                asmReviewNotes.toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'ASM Notes:',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                asmReviewNotes.toString(),
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDisplayDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date.toString());
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  bool _isSubmissionActionable() {
    final state = _submission?['state']?.toString().toLowerCase() ?? '';
    return state == 'pendinghqapproval';
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
        final base64Content =
            response.data['base64Content']?.toString() ?? '';
        final contentType = response.data['contentType']?.toString() ??
            'application/octet-stream';
        final name = filename ??
            response.data['filename']?.toString() ??
            'document';

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
        final blob = web.Blob(
          [bytes.toJS].toJS,
          web.BlobPropertyBag(type: contentType),
        );
        final url = web.URL.createObjectURL(blob);

        final anchor =
            web.document.createElement('a') as web.HTMLAnchorElement;
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
}
