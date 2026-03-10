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
import '../../../approval/data/models/invoice_summary_data.dart';
import '../../../approval/data/models/campaign_detail_row.dart';
import '../../../approval/presentation/utils/submission_data_transformer.dart';
import '../../../approval/presentation/widgets/invoice_summary_section.dart';
import '../../../approval/presentation/widgets/campaign_details_table.dart';

class AgencySubmissionDetailPage extends StatefulWidget {
  final String submissionId;
  final String token;
  final String userName;

  const AgencySubmissionDetailPage({
    super.key,
    required this.submissionId,
    required this.token,
    required this.userName,
  });

  @override
  State<AgencySubmissionDetailPage> createState() => _AgencySubmissionDetailPageState();
}

class _AgencySubmissionDetailPageState extends State<AgencySubmissionDetailPage> {
  final _dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'));

  bool _isLoading = true;
  Map<String, dynamic>? _submission;
  String? _errorMessage;
  bool _isChatOpen = false;
  bool _isSidebarCollapsed = true;

  // Transformed data for ASM-style layout
  InvoiceSummaryData? _invoiceSummary;
  List<CampaignDetailRow> _campaignDetails = [];

  @override
  void initState() {
    super.initState();
    _loadSubmissionDetails();
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
        final invoiceSummary = SubmissionDataTransformer.extractInvoiceSummary(submissionData);
        final campaignDetails = SubmissionDataTransformer.transformToCampaignDetails(submissionData);
        
        setState(() {
          _submission = submissionData;
          _invoiceSummary = invoiceSummary;
          _campaignDetails = campaignDetails;
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

  void _navigateToUpload() {
    Navigator.pushNamed(context, '/agency/upload', arguments: {
      'token': widget.token,
      'userName': widget.userName,
    });
  }

  List<NavItem> _getNavItems(BuildContext context) {
    return [
      NavItem(icon: Icons.dashboard, label: 'Dashboard', onTap: () => Navigator.pop(context)),
      NavItem(icon: Icons.upload_file, label: 'Upload', onTap: _navigateToUpload),
      NavItem(icon: Icons.visibility, label: 'View Request', isActive: true, onTap: () {}),
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
              Text('Agency', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
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
                  title: const Text('Bajaj', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                        userRole: 'Agency',
                        navItems: _getNavItems(context),
                        onLogout: () => Navigator.pushReplacementNamed(context, '/'),
                        isCollapsed: _isSidebarCollapsed,
                        onToggleCollapse: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
                      ),
                    Expanded(
                      child: Column(
                        children: [
                          if (!isMobile) _buildDesktopHeader(device),
                          Expanded(
                            child: _isLoading
                                ? const Center(child: CircularProgressIndicator())
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

  Widget _buildDesktopHeader(DeviceType device) {
    final fapNumber = 'FAP-${widget.submissionId.length >= 8 ? widget.submissionId.substring(0, 8).toUpperCase() : widget.submissionId.toUpperCase()}';
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
                Text('Submission Details', style: AppTextStyles.h2),
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
    final fapNumber = 'FAP-${widget.submissionId.length >= 8 ? widget.submissionId.substring(0, 8).toUpperCase() : widget.submissionId.toUpperCase()}';
    final hPad = responsiveValue<double>(MediaQuery.of(context).size.width, mobile: 12, tablet: 16, desktop: 24);

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
                      Text('Submission Details', style: AppTextStyles.h2),
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
          if (state.toLowerCase() == 'rejectedbyhq' || state.toLowerCase() == 'rejectedbyra') ...[
            const SizedBox(height: 16),
            _buildRejectionCard(
              rejectedBy: 'RA',
              reviewNotes: _submission!['hqReviewNotes']?.toString(),
            ),
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
            onPhotoTap: (detail) => _downloadDocument(detail.documentId, detail.documentName),
          ),
          const SizedBox(height: 24),

          // Hierarchical Campaign Data (Campaigns → Invoices, Photos, Cost/Activity Summaries)
          _buildCampaignsSection(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String state, String fapNumber) {
    final statusInfo = _getStatusInfo(state);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildInfoItem('Submitted', _formatDate(_submission!['createdAt']))),
                Expanded(child: _buildInfoItem('Last Updated', _formatDate(_submission!['updatedAt']))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
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
                    children: data.entries
                      .where((entry) => !const {'LineItems', 'FieldConfidences', 'IsFlaggedForReview'}.contains(entry.key))
                      .map((entry) {
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

  bool _isResubmitting = false;

  Widget _buildRejectionCard({required String rejectedBy, String? reviewNotes}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFEF4444))),
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
                  style: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF7F1D1D)),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isResubmitting ? null : _resubmitPackage,
                icon: _isResubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.refresh),
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

  Future<void> _resubmitPackage() async {
    setState(() => _isResubmitting = true);
    try {
      final response = await _dio.patch(
        '/submissions/${widget.submissionId}/resubmit',
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );
      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request resubmitted successfully'), backgroundColor: Color(0xFF10B981)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resubmit: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isResubmitting = false);
    }
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
              // Campaign details row
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  if (startDate != 'N/A') _buildDetailChip('Start', startDate),
                  if (endDate != 'N/A') _buildDetailChip('End', endDate),
                  if (workingDays.isNotEmpty) _buildDetailChip('Working Days', workingDays),
                  if (totalCost != null) _buildDetailChip('Total Cost', '₹$totalCost'),
                ],
              ),
              const SizedBox(height: 16),

              // Cost Summary
              if (costSummaryUrl != null && costSummaryUrl.isNotEmpty)
                _buildDocumentRow(Icons.summarize, costSummaryFile ?? 'Cost Summary', costSummaryUrl),

              // Activity Summary
              if (activitySummaryUrl != null && activitySummaryUrl.isNotEmpty)
                _buildDocumentRow(Icons.assignment, activitySummaryFile ?? 'Activity Summary', activitySummaryUrl),

              // Invoices
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
                  return _buildDocumentRow(Icons.receipt, label, blobUrl);
                }),
              ],

              // Photos
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
                  return _buildDocumentRow(Icons.image, label, blobUrl);
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

  Widget _buildDocumentRow(IconData icon, String label, String? blobUrl) {
    final hasUrl = blobUrl != null && blobUrl.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: hasUrl ? AppColors.primary : AppColors.textSecondary),
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
    } else if (state.contains('approved') || state.contains('pendinghq') || state.contains('rejectedbyhq')) {
      asmStatus = 'approved';
    } else if (asmReviewedAt != null) {
      asmStatus = asmReviewNotes != null && asmReviewNotes.isNotEmpty ? 'rejected' : 'approved';
    }

    // Determine HQ/RA status
    String hqStatus = 'pending';
    if (state == 'approved') {
      hqStatus = 'approved';
    } else if (state.contains('rejectedbyhq')) {
      hqStatus = 'rejected';
    } else if (hqReviewedAt != null) {
      hqStatus = hqReviewNotes != null && hqReviewNotes.isNotEmpty ? 'rejected' : 'approved';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Approval Flow', style: AppTextStyles.h3),
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
                  ? 'Approved by ASM'
                  : asmStatus == 'rejected'
                      ? 'Rejected by ASM'
                      : 'Pending ASM Review',
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
                    color: isCompleted ? color.withOpacity(0.15) : const Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                    border: Border.all(color: isCompleted ? color : const Color(0xFFD1D5DB), width: 2),
                  ),
                  child: Icon(icon, size: 14, color: isCompleted ? color : const Color(0xFF9CA3AF)),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isCompleted ? color.withOpacity(0.3) : const Color(0xFFE5E7EB),
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
                      color: isCompleted ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                    ),
                  ),
                  if (date != null) ...[
                    const SizedBox(height: 2),
                    Text(date, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11)),
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
                        style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF4B5563), height: 1.4),
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
        'label': 'Rejected by ASM',
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
    } else if (stateLower.contains('pendinghq') || stateLower == 'asmapproved') {
      return {
        'label': 'Pending with RA',
        'color': const Color(0xFF3B82F6),
        'bgColor': const Color(0xFFDBEAFE),
        'borderColor': const Color(0xFF93C5FD),
        'icon': Icons.hourglass_empty,
      };
    } else if (stateLower.contains('pendingasm') || stateLower.contains('pendingapproval')) {
      return {
        'label': 'Pending with ASM',
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
        const SnackBar(content: Text('Document not available for download'), backgroundColor: Colors.orange),
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

        if (mounted) {
          _showDocumentPreview(bytes, contentType, name);
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
