import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class AgencyDashboardPage extends StatefulWidget {
  final String token;
  final String userName;

  const AgencyDashboardPage({
    super.key,
    required this.token,
    required this.userName,
  });

  @override
  State<AgencyDashboardPage> createState() => _AgencyDashboardPageState();
}

class _AgencyDashboardPageState extends State<AgencyDashboardPage> {
  final _dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'));
  final _searchController = TextEditingController();
  final _chatController = TextEditingController();
  
  String _statusFilter = 'all';
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  bool _isChatOpen = false;
  List<Map<String, dynamic>> _chatMessages = [];
  bool _isSendingMessage = false;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    try {
      final response = await _dio.get(
        '/submissions',
        options: Options(
          headers: {'Authorization': 'Bearer ${widget.token}'},
        ),
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          // Backend returns paginated response: { total, page, pageSize, items }
          final data = response.data;
          if (data is Map && data.containsKey('items')) {
            _requests = List<Map<String, dynamic>>.from(data['items']);
          } else {
            _requests = [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading requests: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load requests: ${e.toString()}'),
            backgroundColor: AppColors.rejectedText,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredRequests {
    return _requests.where((req) {
      final matchesSearch = _searchController.text.isEmpty ||
          req['id'].toString().toLowerCase().contains(_searchController.text.toLowerCase());
      
      if (_statusFilter == 'all') return matchesSearch;
      
      final state = req['state']?.toString().toLowerCase() ?? '';
      bool matchesStatus = false;
      
      switch (_statusFilter) {
        case 'pending':
          matchesStatus = state == 'uploaded' || state == 'extracting' || state == 'validating' || state == 'scoring';
          break;
        case 'under_review':
          matchesStatus = state == 'validated' || state == 'recommending' || state == 'pendingapproval';
          break;
        case 'approved':
          matchesStatus = state == 'approved';
          break;
        case 'rejected':
          matchesStatus = state == 'rejected' || state == 'validationfailed' || state == 'reuploadrequested';
          break;
      }
      
      return matchesSearch && matchesStatus;
    }).toList();
  }

  Map<String, int> get _stats {
    return {
      'total': _requests.length,
      'pending': _requests.where((r) {
        final state = r['state']?.toString().toLowerCase() ?? '';
        return state == 'uploaded' || state == 'extracting' || state == 'validating' || state == 'scoring';
      }).length,
      'underReview': _requests.where((r) {
        final state = r['state']?.toString().toLowerCase() ?? '';
        return state == 'validated' || state == 'recommending' || state == 'pendingapproval';
      }).length,
      'approved': _requests.where((r) => r['state']?.toString().toLowerCase() == 'approved').length,
      'rejected': _requests.where((r) {
        final state = r['state']?.toString().toLowerCase() ?? '';
        return state == 'rejected' || state == 'validationfailed' || state == 'reuploadrequested';
      }).length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(),
          
          // Main Content (automatically adjusts based on chat panel)
          Expanded(
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
          
          // AI Chat Panel (fixed on the right, full height)
          if (_isChatOpen) _buildChatPanel(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            _isChatOpen = !_isChatOpen;
          });
        },
        icon: Icon(_isChatOpen ? Icons.close : Icons.chat),
        label: Text(_isChatOpen ? 'Close Chat' : 'AI Assistant'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
        ),
      ),
      child: Column(
        children: [
          // Logo/Brand
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.business,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Bajaj',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          Divider(height: 1, color: Colors.white.withOpacity(0.2)),
          
          // Navigation Items
          _buildNavItem(Icons.dashboard, 'Dashboard', true, () {}),
          _buildNavItem(Icons.upload_file, 'Upload', false, () {
            Navigator.pushNamed(
              context,
              '/agency/upload',
              arguments: {
                'token': widget.token,
                'userName': widget.userName,
              },
            );
          }),
          _buildNavItem(Icons.notifications, 'Notifications', false, () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notifications coming soon')),
            );
          }),
          _buildNavItem(Icons.settings, 'Settings', false, () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings coming soon')),
            );
          }),
          
          const Spacer(),
          
          // User Info
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    widget.userName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.userName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Agency',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Logout
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/');
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        dense: true,
        onTap: onTap,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('All Requests', style: AppTextStyles.h2),
                const SizedBox(height: 4),
                Text(
                  'View and track all your reimbursement requests',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/agency/upload',
                arguments: {
                  'token': widget.token,
                  'userName': widget.userName,
                },
              );
            },
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Create New Request'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildStatsCards(),
          ),
          const SizedBox(height: 24),
          
          // Recent Requests Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Requests',
                      style: AppTextStyles.h3.copyWith(fontSize: 18),
                    ),
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String>(
                        value: _statusFilter,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Status')),
                          DropdownMenuItem(value: 'pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'under_review', child: Text('Under Review')),
                          DropdownMenuItem(value: 'approved', child: Text('Approved')),
                          DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _statusFilter = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildRequestsTable(),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final stats = _stats;
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Pending Requests',
            stats['pending']!,
            Icons.schedule,
            const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Approved This Month',
            stats['approved']!,
            Icons.check_circle,
            const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Total Reimbursed',
            '₹${_calculateTotalAmount()}',
            Icons.account_balance_wallet,
            const Color(0xFF8B5CF6),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Drafts',
            stats['rejected']!,
            Icons.drafts,
            const Color(0xFFF59E0B),
          ),
        ),
      ],
    );
  }

  String _calculateTotalAmount() {
    // Mock calculation - in real app, sum from approved requests
    return '6,60,000';
  }

  Widget _buildStatCard(String label, dynamic value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
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
                    value.toString(),
                    style: AppTextStyles.h2.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsTable() {
    final filtered = _filteredRequests;
    
    if (filtered.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.description,
                  size: 64,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No requests found',
                  style: AppTextStyles.h3,
                ),
                const SizedBox(height: 8),
                Text(
                  _searchController.text.isNotEmpty || _statusFilter != 'all'
                      ? 'Try adjusting your filters'
                      : 'Create your first request to get started',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/agency/upload',
                      arguments: {
                        'token': widget.token,
                        'userName': widget.userName,
                      },
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create New Request'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
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
                const SizedBox(width: 80), // Space for View column
              ],
            ),
          ),
          // Table Rows
          ...filtered.asMap().entries.map((entry) {
            final request = entry.value;
            return _buildTableRow(request);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> request) {
    final status = _normalizeStatus(request['state']?.toString() ?? 'pending');
    final fapNumber = 'FAP-${request['id']?.toString().substring(0, 8).toUpperCase() ?? 'UNKNOWN'}';
    
    // Get PO data from API
    var poNumber = request['poNumber']?.toString() ?? '-';
    var poAmount = request['poAmount'];
    
    // Get invoice data from API
    var invoiceNumber = request['invoiceNumber']?.toString() ?? '-';
    var invoiceAmount = request['invoiceAmount'];
    
    // Format amounts
    final poAmountStr = poAmount != null 
        ? '₹${double.parse(poAmount.toString()).toStringAsFixed(2)}' 
        : '-';
    final invoiceAmountStr = invoiceAmount != null 
        ? '₹${double.parse(invoiceAmount.toString()).toStringAsFixed(2)}' 
        : '-';
    
    // AI Confidence Score from API
    final overallConfidence = request['overallConfidence'];
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
              _formatDate(request['createdAt']),
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
              child: _getStatusBadge(status),
            ),
          ),
          SizedBox(
            width: 80,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.visibility_outlined),
                color: AppColors.primary,
                onPressed: () {
                  // Show detailed view dialog
                  _showSubmissionDetails(request);
                },
                tooltip: 'View Details',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getStatusBadge(String status) {
    Color bgColor, textColor;
    String label;
    
    switch (status) {
      case 'approved':
        bgColor = AppColors.approvedBackground;
        textColor = AppColors.approvedText;
        label = 'Submitted';
        break;
      case 'rejected':
        bgColor = AppColors.rejectedBackground;
        textColor = AppColors.rejectedText;
        label = 'Draft';
        break;
      case 'under_review':
        bgColor = AppColors.reviewBackground;
        textColor = AppColors.reviewText;
        label = 'On Hold';
        break;
      default:
        bgColor = AppColors.pendingBackground;
        textColor = AppColors.pendingText;
        label = 'Submitted';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'under_review':
        return 'Under Review';
      default:
        return 'Pending';
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

  String _normalizeStatus(String backendState) {
    final state = backendState.toLowerCase();
    
    // Map backend states to UI states
    if (state == 'uploaded' || state == 'extracting' || state == 'validating' || state == 'scoring') {
      return 'pending';
    } else if (state == 'validated' || state == 'recommending' || state == 'pendingapproval') {
      return 'under_review';
    } else if (state == 'approved') {
      return 'approved';
    } else if (state == 'rejected' || state == 'validationfailed' || state == 'reuploadrequested') {
      return 'rejected';
    }
    
    return 'pending';
  }

  void _showSubmissionDetails(Map<String, dynamic> request) {
    final fapNumber = 'FAP-${request['id']?.toString().substring(0, 8).toUpperCase() ?? 'UNKNOWN'}';
    final status = _normalizeStatus(request['state']?.toString() ?? 'pending');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Submission Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('FAP Number', fapNumber),
              _buildDetailRow('Status', _getStatusLabel(status)),
              _buildDetailRow('Submitted Date', _formatDate(request['createdAt'])),
              _buildDetailRow('Last Updated', _formatDate(request['updatedAt'])),
              _buildDetailRow('Documents', '${request['documentCount'] ?? 0} files'),
              const SizedBox(height: 16),
              Text(
                'Note: Full details will be available after AI processing.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPanel() {
    return Container(
      width: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: AppColors.border),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Chat Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.smart_toy,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Assistant',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Ask me anything about your submissions',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _isChatOpen = false;
                    });
                  },
                ),
              ],
            ),
          ),
          
          // Chat Messages
          Expanded(
            child: _chatMessages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start a conversation',
                          style: AppTextStyles.h4.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Ask about your submissions, status updates, or any questions you have',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildSuggestedQuestion('What is my latest submission status?'),
                            _buildSuggestedQuestion('How many pending requests do I have?'),
                            _buildSuggestedQuestion('Show me approved submissions'),
                          ],
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _chatMessages.length,
                    itemBuilder: (context, index) {
                      final message = _chatMessages[index];
                      final isUser = message['isUser'] as bool;
                      return _buildChatMessage(
                        message['text'] as String,
                        isUser,
                      );
                    },
                  ),
          ),
          
          // Chat Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    enabled: !_isSendingMessage,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isSendingMessage ? null : _sendMessage,
                  icon: _isSendingMessage
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedQuestion(String question) {
    return InkWell(
      onTap: () {
        _chatController.text = question;
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Text(
          question,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildChatMessage(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isUser ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_chatController.text.trim().isEmpty) return;

    final userMessage = _chatController.text.trim();
    _chatController.clear();

    setState(() {
      _chatMessages.add({'text': userMessage, 'isUser': true});
      _isSendingMessage = true;
    });

    try {
      // Call chat API
      final response = await _dio.post(
        '/chat/message',
        data: {'message': userMessage},
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _chatMessages.add({
            'text': response.data['response'] ?? 'I received your message.',
            'isUser': false,
          });
        });
      }
    } catch (e) {
      // Mock response for demo
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _chatMessages.add({
            'text': _getMockResponse(userMessage),
            'isUser': false,
          });
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingMessage = false;
        });
      }
    }
  }

  String _getMockResponse(String message) {
    final lowerMessage = message.toLowerCase();
    
    if (lowerMessage.contains('status') || lowerMessage.contains('latest')) {
      return 'You have ${_requests.length} total submissions. ${_stats['pending']} are pending review.';
    } else if (lowerMessage.contains('pending')) {
      return 'You currently have ${_stats['pending']} pending requests waiting for review.';
    } else if (lowerMessage.contains('approved')) {
      return 'You have ${_stats['approved']} approved submissions this month.';
    } else if (lowerMessage.contains('help')) {
      return 'I can help you with:\n• Check submission status\n• View pending requests\n• Get approval statistics\n• Answer questions about your submissions';
    } else {
      return 'I understand your question. The AI chat service will be available once Azure OpenAI is configured. For now, you can view your submissions in the dashboard.';
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
