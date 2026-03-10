import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
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
import '../../data/models/invoice_summary_data.dart';
import '../../data/models/invoice_document_row.dart';
import '../../data/models/campaign_detail_row.dart';
import '../utils/submission_data_transformer.dart';
import '../widgets/invoice_summary_section.dart';
import '../widgets/invoice_documents_table.dart';
import '../widgets/campaign_details_table.dart';
import '../widgets/hq_rejection_section.dart';
import '../widgets/ai_analysis_section.dart';

class ASMReviewDetailPage extends StatefulWidget {
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
  State<ASMReviewDetailPage> createState() => _ASMReviewDetailPageState();
}

class _ASMReviewDetailPageState extends State<ASMReviewDetailPage> {
  final _dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:5000/api',
    // Disable caching
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
  bool _isChatOpen = false;
  bool _isSidebarCollapsed = true;
  
  // Transformed data for new layout
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
        
        // Transform data for new layout
        final invoiceSummary = SubmissionDataTransformer.extractInvoiceSummary(submissionData);
        final invoiceDocuments = SubmissionDataTransformer.transformToInvoiceDocuments(submissionData);
        final campaignDetails = SubmissionDataTransformer.transformToCampaignDetails(submissionData);
        
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
        data: {'reason': reason},
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
      NavItem(icon: Icons.dashboard, label: 'Dashboard', onTap: () => Navigator.pop(context)),
      NavItem(icon: Icons.rate_review, label: 'Review', isActive: true, onTap: () {}),
      NavItem(icon: Icons.notifications, label: 'Notifications', onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications coming soon')));
      }),
      NavItem(icon: Icons.settings, label: 'Settings', onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings coming soon')));
      }),
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
          ),
          const Spacer(),
          CircleAvatar(
            backgroundColor: Colors.white,
            radius: 18,
            child: Text(
              widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : '?',
              style: const TextStyle(color: Color(0xFF003087), fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.userName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 2),
              Text('ASM', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
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
                  title: const Text('Bajaj', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  iconTheme: const IconThemeData(color: Colors.white),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Back',
                    ),
                  ],
                )
              : null,
          drawer: isMobile
              ? AppDrawer(
                  userName: widget.userName,
                  userRole: 'ASM',
                  navItems: _getNavItems(context),
                  onLogout: () => Navigator.pushReplacementNamed(context, '/'),
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
                        onLogout: () => Navigator.pushReplacementNamed(context, '/'),
                        isCollapsed: _isSidebarCollapsed,
                        onToggleCollapse: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
                      ),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _submission == null
                              ? const Center(child: Text('Submission not found'))
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildHeaderSection(),
                                      const SizedBox(height: 24),
                                      if (_invoiceSummary != null)
                                        InvoiceSummarySection(data: _invoiceSummary!),
                                      const SizedBox(height: 24),
                                      AiAnalysisSection(submission: _submission!),
                                      const SizedBox(height: 24),
                                      HQRejectionSection(
                                        state: _submission!['state']?.toString() ?? '',
                                        hqReviewedAt: _submission!['hqReviewedAt'],
                                        hqReviewNotes: _submission!['hqReviewNotes'],
                                        onResubmit: _showResubmitToHQDialog,
                                      ),
                                      const SizedBox(height: 24),
                                      InvoiceDocumentsTable(
                                        documents: _invoiceDocuments,
                                        onDocumentTap: (doc) {
                                          if (doc.documentId != null && doc.documentId!.isNotEmpty) {
                                            _downloadDocument(doc.documentId, doc.documentName);
                                          } else {
                                            _downloadDocumentByUrl(doc.blobUrl, doc.documentName);
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 24),
                                      CampaignDetailsTable(
                                        campaignDetails: _campaignDetails,
                                        onPhotoTap: (detail) {
                                          if (detail.documentId != null && detail.documentId!.isNotEmpty) {
                                            _downloadDocument(detail.documentId, detail.documentName);
                                          } else {
                                            _downloadDocumentByUrl(detail.blobUrl, detail.documentName);
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 80),
                                    ],
                                  ),
                                ),
                    ),
                    if (_isChatOpen && !isMobile)
                      ChatSidePanel(
                        token: widget.token,
                        deviceType: device,
                        onClose: () => setState(() => _isChatOpen = false),
                      ),
                  ],
                ),
              ),
            ],
          ),
          endDrawer: isMobile ? ChatEndDrawer(token: widget.token) : null,
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
    String reqNumber = 'REQ-${widget.submissionId.substring(0, 8).toUpperCase()}';
    
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
            invoiceNumber = data['InvoiceNumber'] ?? data['invoiceNumber'] ?? '';
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
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Reject'),
                  ),
                  OutlinedButton(
                    onPressed: _isProcessing ? null : _showRejectDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF59E0B),
                      side: const BorderSide(color: Color(0xFFF59E0B)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Send Back'),
                  ),
                  ElevatedButton(
                    onPressed: _isProcessing ? null : _approveSubmission,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
    
    if (normalizedState == 'pendingapproval' || normalizedState == 'pending') {
      backgroundColor = const Color(0xFFDEEAFF);
      textColor = const Color(0xFF0066FF);
      displayText = 'Submitted';
    } else if (normalizedState == 'approved') {
      backgroundColor = const Color(0xFFD1FAE5);
      textColor = const Color(0xFF10B981);
      displayText = 'Approved';
    } else if (normalizedState == 'rejectedbyhq') {
      backgroundColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFEF4444);
      displayText = 'Rejected by HQ';
    } else if (normalizedState == 'rejected') {
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
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (e) {
      return '';
    }
  }

  bool _isSubmissionActionable() {
    final state = _submission?['state']?.toString().toLowerCase() ?? '';
    // Action buttons and comments should only be visible for PendingApproval, PendingASMApproval, or RejectedByHQ states
    return state == 'pendingapproval' || 
           state == 'pendingasmapproval' || 
           state == 'rejectedbyhq';
  }

  void _showResubmitToHQDialog() {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resubmit to HQ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide notes explaining what has been addressed or corrected:',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter your notes here...',
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
              if (notesController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide notes before resubmitting'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _resubmitToHQ(notesController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Resubmit'),
          ),
        ],
      ),
    );
  }

  Future<void> _resubmitToHQ(String notes) async {
    try {
      final response = await _dio.patch(
        '/submissions/${widget.submissionId}/resubmit-to-hq',
        data: {'notes': notes},
        options: Options(
          headers: {'Authorization': 'Bearer ${widget.token}'},
        ),
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Package resubmitted to HQ successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to review list
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resubmit to HQ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPOSection() {
    if (_submission == null) return const SizedBox();
    final documents = _submission!['documents'] as List? ?? [];
    final poDocs = documents.where((d) => d['type'] == 'PO').toList();
    if (poDocs.isEmpty) return const SizedBox();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.description, color: Color(0xFF3B82F6), size: 32),
        title: Text('Purchase Order', style: AppTextStyles.h3),
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
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download, size: 20),
                      onPressed: () => _downloadDocument(doc['id']?.toString(), doc['filename']),
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
                    children: data.entries.map((entry) {
                      return SizedBox(
                        width: 200,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatFieldName(entry.key),
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.value?.toString() ?? '-',
                              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
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
    return key.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(0)}',
    ).trim().split(' ').map((word) =>
      word[0].toUpperCase() + word.substring(1),
    ).join(' ');
  }

  Widget _buildCampaignsSection() {
    if (_submission == null) return const SizedBox();
    final campaigns = _submission!['campaigns'] as List? ?? [];
    if (campaigns.isEmpty) return const SizedBox();

    return Card(
      elevation: 0,
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
                Text('Campaigns (${campaigns.length})', style: AppTextStyles.h3),
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
    final name = campaign['campaignName']?.toString() ?? 'Campaign ${index + 1}';
    final teamCode = campaign['teamCode']?.toString() ?? '';
    final dealership = campaign['dealershipName']?.toString() ?? '';
    final startDate = _formatDisplayDate(campaign['startDate']);
    final endDate = _formatDisplayDate(campaign['endDate']);
    final workingDays = campaign['workingDays']?.toString() ?? '';
    final totalCost = campaign['totalCost'];
    final invoices = campaign['invoices'] as List? ?? [];
    final photos = campaign['photos'] as List? ?? [];
    final costSummaryUrl = campaign['costSummaryBlobUrl']?.toString();
    final costSummaryFile = campaign['costSummaryFileName']?.toString();
    final activitySummaryUrl = campaign['activitySummaryBlobUrl']?.toString();
    final activitySummaryFile = campaign['activitySummaryFileName']?.toString();

    return ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF3B82F6).withOpacity(0.1),
        child: Text('${index + 1}', style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
      ),
      title: Text(name, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(
        [if (teamCode.isNotEmpty) 'Team: $teamCode', if (dealership.isNotEmpty) dealership].join(' • '),
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
      ),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  if (startDate.isNotEmpty) _buildDetailChip('Start', startDate),
                  if (endDate.isNotEmpty) _buildDetailChip('End', endDate),
                  if (workingDays.isNotEmpty) _buildDetailChip('Working Days', workingDays),
                  if (totalCost != null) _buildDetailChip('Total Cost', '₹$totalCost'),
                ],
              ),
              const SizedBox(height: 16),
              if (costSummaryUrl != null && costSummaryUrl.isNotEmpty)
                _buildCampaignDocRow(Icons.summarize, costSummaryFile ?? 'Cost Summary', costSummaryUrl),
              if (activitySummaryUrl != null && activitySummaryUrl.isNotEmpty)
                _buildCampaignDocRow(Icons.assignment, activitySummaryFile ?? 'Activity Summary', activitySummaryUrl),
              if (invoices.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Invoices (${invoices.length})', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
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
                  return _buildCampaignDocRow(Icons.receipt, label, blobUrl);
                }),
              ],
              if (photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Photos (${photos.length})', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...photos.map((photo) {
                  final photoMap = photo as Map<String, dynamic>;
                  final fileName = photoMap['fileName']?.toString() ?? 'Photo';
                  final blobUrl = photoMap['blobUrl']?.toString() ?? '';
                  final caption = photoMap['caption']?.toString() ?? '';
                  final label = caption.isNotEmpty ? '$fileName - $caption' : fileName;
                  return _buildCampaignDocRow(Icons.image, label, blobUrl);
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildCampaignDocRow(IconData icon, String label, String? blobUrl) {
    final hasUrl = blobUrl != null && blobUrl.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: hasUrl ? AppColors.primary : AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: AppTextStyles.bodyMedium, overflow: TextOverflow.ellipsis),
          ),
          if (hasUrl)
            IconButton(
              icon: const Icon(Icons.download, size: 18),
              onPressed: () => _downloadDocumentByUrl(blobUrl, label),
              tooltip: 'Download',
              color: AppColors.primary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }

  void _downloadDocumentByUrl(String? blobUrl, String? filename) {
    if (blobUrl == null || blobUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document URL not available'), backgroundColor: Colors.orange),
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
          SnackBar(content: Text('Failed to open document: $e'), backgroundColor: Colors.red),
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
        final contentType =
            response.data['contentType']?.toString() ?? 'application/octet-stream';
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
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
                                  const Icon(Icons.insert_drive_file, size: 64, color: AppColors.textSecondary),
                                  const SizedBox(height: 16),
                                  Text(name, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  Text('Preview not available for this file type.\nClick "Download" to save.', 
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
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
                        final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
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
