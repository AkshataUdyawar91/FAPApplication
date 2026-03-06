import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:html' as html;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

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
        setState(() {
          _submission = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading submission details: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load submission details';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.gradientBlue,
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : _errorMessage != null
                      ? _buildError()
                      : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              const Text(
                'Submission Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Logged in as',
                    style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 12),
                  ),
                  Text(
                    widget.userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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

  Widget _buildContent() {
    if (_submission == null) return const SizedBox();

    final state = _submission!['state']?.toString() ?? 'Unknown';
    final fapNumber = 'FAP-${widget.submissionId.substring(0, 8).toUpperCase()}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(state, fapNumber),
            const SizedBox(height: 24),
            if (_submission!['asmReviewNotes'] != null) ...[
              _buildRejectionCard('ASM', _submission!['asmReviewNotes'], _submission!['asmReviewedAt']),
              const SizedBox(height: 24),
            ],
            if (_submission!['hqReviewNotes'] != null) ...[
              _buildRejectionCard('HQ', _submission!['hqReviewNotes'], _submission!['hqReviewedAt']),
              const SizedBox(height: 24),
            ],
            _buildDocumentsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String state, String fapNumber) {
    final statusInfo = _getStatusInfo(state);
    
    return Card(
      elevation: 4,
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
                      Text(
                        fapNumber,
                        style: AppTextStyles.h2,
                      ),
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
                Expanded(
                  child: _buildInfoItem('Submitted', _formatDate(_submission!['createdAt'])),
                ),
                Expanded(
                  child: _buildInfoItem('Last Updated', _formatDate(_submission!['updatedAt'])),
                ),
                if (_submission!['confidenceScore'] != null)
                  Expanded(
                    child: _buildInfoItem(
                      'AI Confidence',
                      '${(_submission!['confidenceScore']['overallConfidence'] * 100).toStringAsFixed(0)}%',
                    ),
                  ),
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
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRejectionCard(String reviewer, String notes, dynamic reviewedAt) {
    return Card(
      elevation: 2,
      color: const Color(0xFFFEF2F2),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 24),
                const SizedBox(width: 12),
                Text(
                  'Rejected by $reviewer',
                  style: AppTextStyles.h3.copyWith(
                    color: const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              notes,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Reviewed on: ${_formatDate(reviewedAt)}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsSection() {
    final documents = _submission!['documents'] as List? ?? [];
    
    final poDoc = documents.where((d) => d['type'] == 'PO').toList();
    final invoiceDoc = documents.where((d) => d['type'] == 'Invoice').toList();
    final costSummaryDoc = documents.where((d) => d['type'] == 'CostSummary').toList();
    final photos = documents.where((d) => d['type'] == 'Photo').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (poDoc.isNotEmpty) ...[
          _buildDocumentCard('Purchase Order', poDoc, Icons.description, const Color(0xFF3B82F6)),
          const SizedBox(height: 16),
        ],
        if (invoiceDoc.isNotEmpty) ...[
          _buildDocumentCard('Invoice', invoiceDoc, Icons.receipt_long, const Color(0xFF10B981)),
          const SizedBox(height: 16),
        ],
        if (costSummaryDoc.isNotEmpty) ...[
          _buildDocumentCard('Cost Summary', costSummaryDoc, Icons.calculate, const Color(0xFFF59E0B)),
          const SizedBox(height: 16),
        ],
        if (photos.isNotEmpty) ...[
          _buildPhotosCard(photos),
        ],
      ],
    );
  }

  Widget _buildDocumentCard(String title, List<dynamic> docs, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(
          title,
          style: AppTextStyles.h3,
        ),
        subtitle: Text('${docs.length} document(s)'),
        children: docs.map((doc) {
          final extractedData = doc['extractedData'];
          Map<String, dynamic>? data;
          
          if (extractedData != null && extractedData is String && extractedData.isNotEmpty) {
            try {
              data = Map<String, dynamic>.from(
                const JsonDecoder().convert(extractedData)
              );
            } catch (e) {
              print('Error parsing extracted data: $e');
            }
          }

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
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
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (doc['extractionConfidence'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.pendingBackground,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(doc['extractionConfidence'] * 100).toStringAsFixed(0)}% confidence',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.pendingText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.download, size: 20),
                      onPressed: () => _downloadDocument(doc['blobUrl'], doc['filename']),
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
                  _buildExtractedData(data),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExtractedData(Map<String, dynamic> data) {
    return Wrap(
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
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                entry.value?.toString() ?? '-',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPhotosCard(List<dynamic> photos) {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        leading: const Icon(Icons.photo_library, color: Color(0xFF8B5CF6), size: 32),
        title: Text(
          'Activity Photos',
          style: AppTextStyles.h3,
        ),
        subtitle: Text('${photos.length} photo(s)'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];
                return _buildPhotoTile(photo);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoTile(Map<String, dynamic> photo) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: const Icon(Icons.image, size: 48, color: AppColors.textSecondary),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            child: Text(
              photo['filename'] ?? 'Photo',
              style: AppTextStyles.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
    } else if (stateLower.contains('rejected')) {
      return {
        'label': 'Rejected',
        'color': const Color(0xFFDC2626),
        'bgColor': const Color(0xFFFEE2E2),
        'borderColor': const Color(0xFFFCA5A5),
        'icon': Icons.cancel,
      };
    } else if (stateLower.contains('pendinghq')) {
      return {
        'label': 'Pending HQ Approval',
        'color': const Color(0xFF3B82F6),
        'bgColor': const Color(0xFFDBEAFE),
        'borderColor': const Color(0xFF93C5FD),
        'icon': Icons.hourglass_empty,
      };
    } else if (stateLower.contains('pendingasm') || stateLower.contains('pendingapproval')) {
      return {
        'label': 'Pending ASM Approval',
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

  String _formatFieldName(String key) {
    // Convert camelCase to Title Case
    return key.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(0)}',
    ).trim().split(' ').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  void _downloadDocument(String? blobUrl, String? filename) async {
    if (blobUrl == null || blobUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document URL not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Open document in new browser tab
      html.window.open(blobUrl, '_blank');
      
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
