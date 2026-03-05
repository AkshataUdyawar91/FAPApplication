import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class ASMReviewPage extends StatefulWidget {
  final String token;
  final String userName;

  const ASMReviewPage({
    super.key,
    required this.token,
    required this.userName,
  });

  @override
  State<ASMReviewPage> createState() => _ASMReviewPageState();
}

class _ASMReviewPageState extends State<ASMReviewPage> {
  final _dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'));
  final _searchController = TextEditingController();
  
  String _statusFilter = 'all';
  String _sortBy = 'date';
  bool _isLoading = true;
  List<Map<String, dynamic>> _documents = [];
  
  String _normalizeStatus(String backendState) {
    final state = backendState.toLowerCase();
    
    // Map backend states to ASM UI states
    if (state == 'pendingapproval') {
      return 'asm-review';
    } else if (state == 'approved') {
      return 'approved';
    } else if (state == 'rejected' || state == 'validationfailed' || state == 'reuploadrequested') {
      return 'rejected';
    }
    
    // Other states are not shown to ASM (still processing)
    return 'processing';
  }
  
  int get _pendingCount => _documents.where((d) {
    final state = d['state']?.toString().toLowerCase() ?? '';
    return state == 'pendingapproval';
  }).length;
  
  int get _approvedCount => _documents.where((d) {
    final state = d['state']?.toString().toLowerCase() ?? '';
    return state == 'approved';
  }).length;
  
  int get _rejectedCount => _documents.where((d) {
    final state = d['state']?.toString().toLowerCase() ?? '';
    return state == 'rejected' || state == 'validationfailed' || state == 'reuploadrequested';
  }).length;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await _dio.get(
        '/submissions',
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );
      
      if (response.statusCode == 200 && mounted) {
        setState(() {
          // Backend returns paginated response: { total, page, pageSize, items }
          final data = response.data;
          if (data is Map && data.containsKey('items')) {
            _documents = List<Map<String, dynamic>>.from(data['items']);
          } else {
            _documents = [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading documents: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load submissions: ${e.toString()}'),
            backgroundColor: AppColors.rejectedText,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredDocuments {
    return _documents.where((doc) {
      final status = _normalizeStatus(doc['state']?.toString() ?? '');
      
      // Don't show documents still in processing
      if (status == 'processing') return false;
      
      final matchesSearch = _searchController.text.isEmpty ||
          doc['id']?.toString().toLowerCase().contains(_searchController.text.toLowerCase()) == true;
      
      final matchesStatus = _statusFilter == 'all' || status == _statusFilter;
      
      return matchesSearch && matchesStatus;
    }).toList();
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
                  ? const Center(child: CircularProgressIndicator())
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
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: () => Navigator.pushReplacementNamed(context, '/'),
              ),
              const SizedBox(width: 8),
              const Text(
                'Back to Login',
                style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 14),
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
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Logout'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF93C5FD)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatsCards(),
            const SizedBox(height: 24),
            _buildFilters(),
            const SizedBox(height: 24),
            _buildDocumentsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(child: _buildStatCard(
          'Pending Review',
          _pendingCount.toString(),
          Icons.schedule,
          const Color(0xFFF59E0B),
        )),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard(
          'Approved',
          _approvedCount.toString(),
          Icons.check_circle,
          const Color(0xFF10B981),
        )),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard(
          'Rejected',
          _rejectedCount.toString(),
          Icons.cancel,
          const Color(0xFFEF4444),
        )),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: AppTextStyles.h1.copyWith(
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(icon, size: 40, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search by agency name or document ID...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Filter by status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Status')),
                      DropdownMenuItem(value: 'asm-review', child: Text('Pending Review')),
                      DropdownMenuItem(value: 'approved', child: Text('Approved')),
                      DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                    ],
                    onChanged: (value) => setState(() => _statusFilter = value!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sortBy,
                    decoration: const InputDecoration(
                      labelText: 'Sort by',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'date', child: Text('Date')),
                      DropdownMenuItem(value: 'amount', child: Text('Amount')),
                      DropdownMenuItem(value: 'confidence', child: Text('Confidence')),
                    ],
                    onChanged: (value) => setState(() => _sortBy = value!),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsList() {
    final filtered = _filteredDocuments;
    
    if (filtered.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Center(
            child: Text(
              'No documents found matching your criteria.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'FAP NUMBER',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'PO NO.',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'PO AMT',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'INVOICE NO.',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'INVOICE AMT',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'SUBMITTED DATE',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'AI SCORE',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'STATUS',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 80), // Space for View button
              ],
            ),
          ),
          // Table Rows
          ...filtered.map((doc) => _buildDocumentRow(doc)).toList(),
        ],
      ),
    );
  }

  Widget _buildDocumentRow(Map<String, dynamic> doc) {
    final status = _normalizeStatus(doc['state']?.toString() ?? '');
    final fapNumber = 'FAP-${doc['id']?.toString().substring(0, 8).toUpperCase() ?? 'UNKNOWN'}';
    
    // Get PO data from API
    var poNumber = doc['poNumber']?.toString() ?? '-';
    var poAmount = doc['poAmount'];
    
    // Get invoice data from API
    var invoiceNumber = doc['invoiceNumber']?.toString() ?? '-';
    var invoiceAmount = doc['invoiceAmount'];
    
    // Format amounts
    final poAmountStr = poAmount != null 
        ? '₹${double.parse(poAmount.toString()).toStringAsFixed(2)}' 
        : '-';
    final invoiceAmountStr = invoiceAmount != null 
        ? '₹${double.parse(invoiceAmount.toString()).toStringAsFixed(2)}' 
        : '-';
    
    // AI Confidence Score from API
    final overallConfidence = doc['overallConfidence'];
    final aiScore = overallConfidence != null 
        ? '${(overallConfidence * 100).toStringAsFixed(0)}%' 
        : '-';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              fapNumber,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              poNumber,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              poAmountStr,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              invoiceNumber,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              invoiceAmountStr,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatDate(doc['createdAt']),
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                aiScore,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: _buildStatusBadge(status),
            ),
          ),
          SizedBox(
            width: 80,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.visibility_outlined),
                color: AppColors.primary,
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/asm/review-detail',
                    arguments: {
                      'submissionId': doc['id'],
                      'token': widget.token,
                      'userName': widget.userName,
                    },
                  );
                },
                tooltip: 'View Details',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color bgColor, textColor, borderColor;
    String label;

    switch (status) {
      case 'asm-review':
        bgColor = AppColors.pendingBackground;
        textColor = AppColors.pendingText;
        borderColor = AppColors.pendingBorder;
        label = 'Pending Review';
        break;
      case 'approved':
        bgColor = AppColors.approvedBackground;
        textColor = AppColors.approvedText;
        borderColor = AppColors.approvedBorder;
        label = 'Approved';
        break;
      case 'rejected':
        bgColor = AppColors.rejectedBackground;
        textColor = AppColors.rejectedText;
        borderColor = AppColors.rejectedBorder;
        label = 'Rejected';
        break;
      default:
        bgColor = AppColors.reviewBackground;
        textColor = AppColors.reviewText;
        borderColor = AppColors.reviewBorder;
        label = status ?? 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'asm-review':
        return 'Pending Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (e) {
      return 'N/A';
    }
  }
}
