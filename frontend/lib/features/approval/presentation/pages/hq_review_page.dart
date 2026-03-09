import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/chat_fab.dart';
import '../widgets/view_validation_report_button.dart';

class HQReviewPage extends StatefulWidget {
  final String token;
  final String userName;

  const HQReviewPage({
    super.key,
    required this.token,
    required this.userName,
  });

  @override
  State<HQReviewPage> createState() => _HQReviewPageState();
}

class _HQReviewPageState extends State<HQReviewPage> {
  final _dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'));
  final _searchController = TextEditingController();
  
  String _statusFilter = 'all';
  String _sortBy = 'date';
  bool _isLoading = true;
  List<Map<String, dynamic>> _documents = [];
  
  String _normalizeStatus(String backendState) {
    final state = backendState.toLowerCase().replaceAll('_', '');
    
    // Map backend states to HQ UI states
    if (state == 'pendinghqapproval') {
      return 'hq-review';
    } else if (state == 'approved') {
      return 'approved';
    } else if (state == 'rejectedbyhq') {
      return 'rejected';
    } else if (state == 'pendingasmapproval' || state == 'uploaded' || state == 'extracting' || state == 'validating' || state == 'scoring' || state == 'recommending') {
      // These are processing states or with ASM - don't show to HQ yet
      return 'processing';
    }
    
    // Unknown state - log it and treat as processing
    print('Unknown state in HQ review: $backendState');
    return 'processing';
  }
  
  int get _pendingCount => _documents.where((d) {
    final state = d['state']?.toString().toLowerCase() ?? '';
    return state == 'pendinghqapproval';
  }).length;
  
  int get _approvedCount => _documents.where((d) {
    final state = d['state']?.toString().toLowerCase() ?? '';
    return state == 'approved';
  }).length;
  
  int get _rejectedCount => _documents.where((d) {
    final state = d['state']?.toString().toLowerCase() ?? '';
    return state == 'rejectedbyhq';
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
      
      print('HQ Review - API Response Status: ${response.statusCode}');
      print('HQ Review - API Response Data: ${response.data}');
      
      if (response.statusCode == 200 && mounted) {
        setState(() {
          final data = response.data;
          if (data is Map && data.containsKey('items')) {
            _documents = List<Map<String, dynamic>>.from(data['items']);
            print('HQ Review - Loaded ${_documents.length} documents');
            
            // Debug: Print each document state
            for (var doc in _documents) {
              final state = doc['state']?.toString() ?? 'null';
              final normalized = _normalizeStatus(state);
              print('HQ Review - Document ${doc['id']}: state=$state, normalized=$normalized');
            }
          } else {
            _documents = [];
            print('HQ Review - No items in response');
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
      
      // HQ should see:
      // - Submissions ready for HQ review (hq-review / PendingHQApproval)
      // - Completed submissions (approved, rejected)
      // But NOT submissions still processing or with ASM
      if (status == 'processing') return false;
      
      final matchesSearch = _searchController.text.isEmpty ||
          doc['id']?.toString().toLowerCase().contains(_searchController.text.toLowerCase()) == true ||
          doc['invoiceNumber']?.toString().toLowerCase().contains(_searchController.text.toLowerCase()) == true ||
          doc['poNumber']?.toString().toLowerCase().contains(_searchController.text.toLowerCase()) == true;
      
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
      floatingActionButton: ChatFAB(
        token: widget.token,
        userName: widget.userName,
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              
              if (isMobile) {
                return Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Colors.white),
                          onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                        ),
                        const Text(
                          'Back to Login',
                          style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                  ],
                );
              }
              
              return Row(
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
              );
            },
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        
        if (isMobile) {
          return Column(
            children: [
              _buildStatCard(
                'Pending HQ Review',
                _pendingCount.toString(),
                Icons.schedule,
                const Color(0xFFF59E0B),
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                'Approved',
                _approvedCount.toString(),
                Icons.check_circle,
                const Color(0xFF10B981),
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                'Rejected',
                _rejectedCount.toString(),
                Icons.cancel,
                const Color(0xFFEF4444),
              ),
            ],
          );
        }
        
        return Row(
          children: [
            Expanded(child: _buildStatCard(
              'Pending HQ Review',
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
      },
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            
            return Column(
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
                isMobile
                    ? Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: _statusFilter,
                            decoration: const InputDecoration(
                              labelText: 'Filter by status',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All Status')),
                              DropdownMenuItem(value: 'hq-review', child: Text('Pending HQ Review')),
                              DropdownMenuItem(value: 'approved', child: Text('Approved')),
                              DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                            ],
                            onChanged: (value) => setState(() => _statusFilter = value!),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
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
                        ],
                      )
                    : Row(
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
                                DropdownMenuItem(value: 'hq-review', child: Text('Pending HQ Review')),
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
            );
          },
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        
        if (isMobile) {
          return Column(
            children: filtered.map((doc) => _buildMobileDocumentCard(doc)).toList(),
          );
        }
        
        return _buildDesktopTable(filtered);
      },
    );
  }
  
  Widget _buildMobileDocumentCard(Map<String, dynamic> doc) {
    final status = _normalizeStatus(doc['state']?.toString() ?? '');
    final fapNumber = 'FAP-${doc['id']?.toString().substring(0, 8).toUpperCase() ?? 'UNKNOWN'}';
    
    var poNumber = doc['poNumber']?.toString() ?? '-';
    var poAmount = doc['poAmount'];
    var invoiceNumber = doc['invoiceNumber']?.toString() ?? '-';
    var invoiceAmount = doc['invoiceAmount'];
    
    final poAmountStr = poAmount != null 
        ? '₹${double.parse(poAmount.toString()).toStringAsFixed(2)}' 
        : '-';
    final invoiceAmountStr = invoiceAmount != null 
        ? '₹${double.parse(invoiceAmount.toString()).toStringAsFixed(2)}' 
        : '-';
    
    final overallConfidence = doc['overallConfidence'];
    final aiScore = overallConfidence != null 
        ? '${(overallConfidence * 100).toStringAsFixed(0)}%' 
        : '-';
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.pushNamed(
            context,
            '/hq/review-detail',
            arguments: {
              'submissionId': doc['id'],
              'token': widget.token,
              'userName': widget.userName,
            },
          );
          
          // Reload documents when returning from detail page
          if (result == true || result == null) {
            _loadDocuments();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    fapNumber,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow('PO Number', poNumber),
              _buildInfoRow('PO Amount', poAmountStr),
              _buildInfoRow('Invoice Number', invoiceNumber),
              _buildInfoRow('Invoice Amount', invoiceAmountStr),
              _buildInfoRow('Submitted', _formatDate(doc['createdAt'])),
              _buildInfoRow('AI Score', aiScore),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ViewValidationReportButton(
                      packageId: doc['id'],
                      isCompact: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.pushNamed(
                          context,
                          '/hq/review-detail',
                          arguments: {
                            'submissionId': doc['id'],
                            'token': widget.token,
                            'userName': widget.userName,
                          },
                        );
                        
                        // Reload documents when returning from detail page
                        if (result == true || result == null) {
                          _loadDocuments();
                        }
                      },
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('View Details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
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
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDesktopTable(List<Map<String, dynamic>> filtered) {
    return Card(
      elevation: 2,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          constraints: const BoxConstraints(minWidth: 1200),
          child: Column(
            children: [
              // Table Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        'FAP NUMBER',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(
                        'PO NO.',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: Text(
                        'PO AMT',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: Text(
                        'INVOICE NO.',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: Text(
                        'INVOICE AMT',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: Text(
                        'SUBMITTED DATE',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        'AI SCORE',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: Text(
                        'STATUS',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 120), // Action column
                  ],
                ),
              ),
              // Table Rows
              ...filtered.map((doc) => _buildDocumentRow(doc)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentRow(Map<String, dynamic> doc) {
    final status = _normalizeStatus(doc['state']?.toString() ?? '');
    final fapNumber = 'FAP-${doc['id']?.toString().substring(0, 8).toUpperCase() ?? 'UNKNOWN'}';
    
    var poNumber = doc['poNumber']?.toString() ?? '-';
    var poAmount = doc['poAmount'];
    var invoiceNumber = doc['invoiceNumber']?.toString() ?? '-';
    var invoiceAmount = doc['invoiceAmount'];
    
    final poAmountStr = poAmount != null 
        ? '₹${double.parse(poAmount.toString()).toStringAsFixed(2)}' 
        : '-';
    final invoiceAmountStr = invoiceAmount != null 
        ? '₹${double.parse(invoiceAmount.toString()).toStringAsFixed(2)}' 
        : '-';
    
    final overallConfidence = doc['overallConfidence'];
    final aiScore = overallConfidence != null 
        ? '${(overallConfidence * 100).toStringAsFixed(0)}%' 
        : '-';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              fapNumber,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              poNumber,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          SizedBox(
            width: 140,
            child: Text(
              poAmountStr,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 160,
            child: Text(
              invoiceNumber,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          SizedBox(
            width: 140,
            child: Text(
              invoiceAmountStr,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 140,
            child: Text(
              _formatDate(doc['createdAt']),
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              aiScore,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 140,
            child: _buildStatusBadge(status),
          ),
          SizedBox(
            width: 120,
            child: Row(
              children: [
                ViewValidationReportButton(
                  packageId: doc['id'],
                  isCompact: true,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 20),
                  color: AppColors.primary,
                  onPressed: () async {
                    final result = await Navigator.pushNamed(
                      context,
                      '/hq/review-detail',
                      arguments: {
                        'submissionId': doc['id'],
                        'token': widget.token,
                        'userName': widget.userName,
                      },
                    );
                    
                    // Reload documents when returning from detail page
                    if (result == true || result == null) {
                      _loadDocuments();
                    }
                  },
                  tooltip: 'View Details',
                ),
              ],
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
      case 'hq-review':
        bgColor = AppColors.pendingBackground;
        textColor = AppColors.pendingText;
        borderColor = AppColors.pendingBorder;
        label = 'Pending HQ Review';
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
