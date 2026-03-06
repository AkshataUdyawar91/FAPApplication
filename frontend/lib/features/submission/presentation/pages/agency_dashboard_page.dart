import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/responsive/responsive.dart';

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
  bool _isChatOpen = true;
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
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          final data = response.data;
          _requests = data is Map && data.containsKey('items')
              ? List<Map<String, dynamic>>.from(data['items'])
              : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load requests: $e'), backgroundColor: AppColors.rejectedText),
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
          matchesStatus = ['uploaded', 'extracting', 'validating'].contains(state);
          break;
        case 'under_review':
          matchesStatus = ['validated', 'recommending', 'pendingapproval'].contains(state);
          break;
        case 'approved':
          matchesStatus = state == 'approved';
          break;
        case 'rejected':
          matchesStatus = ['rejected', 'validationfailed', 'reuploadrequested'].contains(state);
          break;
      }
      return matchesSearch && matchesStatus;
    }).toList();
  }

  Map<String, int> get _stats {
    return {
      'total': _requests.length,
      'pending': _requests.where((r) {
        final s = r['state']?.toString().toLowerCase() ?? '';
        return ['uploaded', 'extracting', 'validating'].contains(s);
      }).length,
      'underReview': _requests.where((r) {
        final s = r['state']?.toString().toLowerCase() ?? '';
        return ['validated', 'recommending', 'pendingapproval'].contains(s);
      }).length,
      'approved': _requests.where((r) => r['state']?.toString().toLowerCase() == 'approved').length,
      'rejected': _requests.where((r) {
        final s = r['state']?.toString().toLowerCase() ?? '';
        return ['rejected', 'validationfailed', 'reuploadrequested'].contains(s);
      }).length,
    };
  }

  String _calculateTotalAmount() => '6,60,000';

  // ─── BUILD ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final device = getDeviceType(width);
        final isMobile = device == DeviceType.mobile;
        final isTablet = device == DeviceType.tablet;

        return Scaffold(
          appBar: isMobile
              ? AppBar(
                  backgroundColor: const Color(0xFF1E3A8A),
                  title: const Text('Bajaj', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  iconTheme: const IconThemeData(color: Colors.white),
                  actions: [
                    IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: _navigateToUpload),
                  ],
                )
              : null,
          drawer: isMobile ? _buildDrawer() : null,
          body: Row(
            children: [
              if (!isMobile) _buildSidebar(isTablet),
              Expanded(
                child: Column(
                  children: [
                    if (!isMobile) _buildHeader(device),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _buildContent(device),
                    ),
                  ],
                ),
              ),
              if (_isChatOpen && !isMobile) _buildChatPanel(device),
            ],
          ),
          endDrawer: isMobile ? _buildChatDrawer() : null,
          floatingActionButton: (_isChatOpen && !isMobile) ? null : Builder(
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
                child: Icon(
                  isMobile ? Icons.smart_toy : Icons.smart_toy,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }

  void _navigateToUpload() {
    Navigator.pushNamed(context, '/agency/upload', arguments: {
      'token': widget.token,
      'userName': widget.userName,
    });
  }

  // ─── DRAWER (mobile) ─────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.business, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Text('Bajaj', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.white.withOpacity(0.2)),
              _buildNavItem(Icons.dashboard, 'Dashboard', true, () => Navigator.pop(context)),
              _buildNavItem(Icons.upload_file, 'Upload', false, () { Navigator.pop(context); _navigateToUpload(); }),
              _buildNavItem(Icons.notifications, 'Notifications', false, () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications coming soon')));
              }),
              _buildNavItem(Icons.settings, 'Settings', false, () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings coming soon')));
              }),
              const Spacer(),
              _buildUserInfo(),
              _buildLogoutButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── SIDEBAR (tablet/desktop) ─────────────────────────────────────────
  Widget _buildSidebar(bool collapsed) {
    final sidebarWidth = collapsed ? 72.0 : 250.0;
    return Container(
      width: sidebarWidth,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(collapsed ? 16 : 24),
            child: collapsed
                ? Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.business, color: Colors.white, size: 24),
                  )
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.business, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text('Bajaj', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
          ),
          Divider(height: 1, color: Colors.white.withOpacity(0.2)),
          if (collapsed) ...[
            _buildCollapsedNavItem(Icons.dashboard, 'Dashboard', true, () {}),
            _buildCollapsedNavItem(Icons.upload_file, 'Upload', false, _navigateToUpload),
            _buildCollapsedNavItem(Icons.notifications, 'Notifications', false, () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications coming soon')));
            }),
            _buildCollapsedNavItem(Icons.settings, 'Settings', false, () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings coming soon')));
            }),
          ] else ...[
            _buildNavItem(Icons.dashboard, 'Dashboard', true, () {}),
            _buildNavItem(Icons.upload_file, 'Upload', false, _navigateToUpload),
            _buildNavItem(Icons.notifications, 'Notifications', false, () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications coming soon')));
            }),
            _buildNavItem(Icons.settings, 'Settings', false, () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings coming soon')));
            }),
          ],
          const Spacer(),
          if (!collapsed) _buildUserInfo(),
          _buildLogoutButton(collapsed: collapsed),
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
        leading: Icon(icon, color: Colors.white, size: 20),
        title: Text(label, style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
        dense: true,
        onTap: onTap,
      ),
    );
  }

  Widget _buildCollapsedNavItem(IconData icon, String tooltip, bool isActive, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(icon: Icon(icon, color: Colors.white, size: 20), onPressed: onTap),
      ),
    );
  }

  Widget _buildUserInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            radius: 16,
            child: Text(widget.userName[0].toUpperCase(), style: const TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.userName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white), overflow: TextOverflow.ellipsis),
                Text('Agency', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton({bool collapsed = false}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: collapsed
          ? Tooltip(
              message: 'Logout',
              child: IconButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                icon: const Icon(Icons.logout, size: 18, color: Colors.white),
              ),
            )
          : OutlinedButton.icon(
              onPressed: () => Navigator.pushReplacementNamed(context, '/'),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.5)),
              ),
            ),
    );
  }

  // ─── HEADER (tablet/desktop) ──────────────────────────────────────────
  Widget _buildHeader(DeviceType device) {
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('All Requests', style: AppTextStyles.h2),
                const SizedBox(height: 4),
                Text('View and track all your reimbursement requests', style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _navigateToUpload,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('New Request'),
          ),
        ],
      ),
    );
  }

  // ─── MAIN CONTENT ─────────────────────────────────────────────────────
  Widget _buildContent(DeviceType device) {
    final hPad = responsiveValue<double>(MediaQuery.of(context).size.width, mobile: 12, tablet: 16, desktop: 24);
    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(hPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (device == DeviceType.mobile) ...[
              Text('All Requests', style: AppTextStyles.h2),
              const SizedBox(height: 4),
              Text('View and track all your reimbursement requests', style: AppTextStyles.bodySmall),
              const SizedBox(height: 16),
            ],
            _buildStatsCards(device),
            const SizedBox(height: 24),
            _buildFilterRow(device),
            const SizedBox(height: 16),
            _buildRequestsList(device),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ─── STATS CARDS ──────────────────────────────────────────────────────
  Widget _buildStatsCards(DeviceType device) {
    final stats = _stats;
    final cards = [
      _StatData('Pending Requests', stats['pending']!.toString(), Icons.schedule, const Color(0xFF3B82F6)),
      _StatData('Approved This Month', stats['approved']!.toString(), Icons.check_circle, const Color(0xFF10B981)),
      _StatData('Total Reimbursed', '₹${_calculateTotalAmount()}', Icons.account_balance_wallet, const Color(0xFF8B5CF6)),
      _StatData('Drafts', stats['rejected']!.toString(), Icons.drafts, const Color(0xFFF59E0B)),
    ];

    // Use LayoutBuilder so cards respond to actual available width, not screen width
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // 4-col when wide enough, 2-col otherwise
        if (w >= 600) {
          return Row(
            children: cards.map((c) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: c == cards.last ? 0 : 12),
                child: _buildStatCard(c.label, c.value, c.icon, c.color, w / 4),
              ),
            )).toList(),
          );
        }
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildStatCard(cards[0].label, cards[0].value, cards[0].icon, cards[0].color, w / 2)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard(cards[1].label, cards[1].value, cards[1].icon, cards[1].color, w / 2)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildStatCard(cards[2].label, cards[2].value, cards[2].icon, cards[2].color, w / 2)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard(cards[3].label, cards[3].value, cards[3].icon, cards[3].color, w / 2)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, double cardWidth) {
    // Use column layout when card is too narrow for side-by-side icon+text
    final useColumn = cardWidth < 200;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: EdgeInsets.all(useColumn ? 14 : 20),
        child: useColumn
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(height: 10),
                  Text(value, style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(value, style: AppTextStyles.h2.copyWith(fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ─── FILTER ROW ───────────────────────────────────────────────────────
  Widget _buildFilterRow(DeviceType device) {
    // Use column layout on mobile OR when content area is narrow (e.g. tablet with chat open)
    final availableWidth = MediaQuery.of(context).size.width;
    final useColumnLayout = device == DeviceType.mobile || availableWidth < 500;

    if (useColumnLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Requests', style: AppTextStyles.h3.copyWith(fontSize: 18)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _statusFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'under_review', child: Text('Under Review')),
                    DropdownMenuItem(value: 'approved', child: Text('Approved')),
                    DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                  ],
                  onChanged: (v) => setState(() => _statusFilter = v!),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _navigateToUpload,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text('Recent Requests', style: AppTextStyles.h3.copyWith(fontSize: 18), overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<String>(
            value: _statusFilter,
            isExpanded: true,
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), isDense: true),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Status')),
              DropdownMenuItem(value: 'pending', child: Text('Pending')),
              DropdownMenuItem(value: 'under_review', child: Text('Under Review')),
              DropdownMenuItem(value: 'approved', child: Text('Approved')),
              DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
            ],
            onChanged: (v) => setState(() => _statusFilter = v!),
          ),
        ),
      ],
    );
  }

  // ─── REQUESTS LIST ────────────────────────────────────────────────────
  Widget _buildRequestsList(DeviceType device) {
    final filtered = _filteredRequests;
    if (filtered.isEmpty) return _buildEmptyState();
    return _buildTable(filtered);
  }

  Widget _buildTable(List<Map<String, dynamic>> requests) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  letterSpacing: 0.4,
                ),
                dataTextStyle: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 12,
                ),
                columnSpacing: 20,
                horizontalMargin: 16,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 72,
                dividerThickness: 1,
                columns: const [
                  DataColumn(label: Text('FAP NUMBER')),
                  DataColumn(label: Text('PO NO.')),
                  DataColumn(label: Text('PO AMT')),
                  DataColumn(label: Text('INVOICE NO.')),
                  DataColumn(label: Text('INVOICE AMT')),
                  DataColumn(label: Text('SUBMITTED DATE')),
                  DataColumn(label: Text('AI SCORE')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: SizedBox.shrink()),
                ],
                rows: requests.map((r) {
                  final rawState = r['state']?.toString() ?? 'pending';
                  final status = _normalizeStatus(rawState);
                  final id = r['id']?.toString() ?? '';
                  final fapNumber = 'FAP-${id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase()}';
                  final poNumber = r['poNumber']?.toString() ?? r['poNo']?.toString() ?? '—';
                  final invoiceNumber = r['invoiceNumber']?.toString() ?? r['invoiceNo']?.toString() ?? '—';
                  final poAmount = r['poAmount'];
                  final invoiceAmount = r['invoiceAmount'];
                  final poAmountStr = poAmount != null
                      ? '₹${double.tryParse(poAmount.toString())?.toStringAsFixed(2) ?? '—'}'
                      : '—';
                  final invoiceAmountStr = invoiceAmount != null
                      ? '₹${double.tryParse(invoiceAmount.toString())?.toStringAsFixed(2) ?? '—'}'
                      : '—';
                  final overallConfidence = r['overallConfidence'];
                  final aiScore = overallConfidence != null
                      ? '${(overallConfidence * 100).toStringAsFixed(0)}%'
                      : '—';
                  return DataRow(cells: [
                    DataCell(Text(fapNumber,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF111827)))),
                    DataCell(Text(poNumber, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(poAmountStr, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(invoiceNumber, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(invoiceAmountStr, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(_formatDate(r['createdAt']), style: const TextStyle(fontSize: 12))),
                    DataCell(Text(aiScore,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                    DataCell(_buildStatusBadge(status, rawState)),
                    DataCell(
                      IconButton(
                        onPressed: () => _showSubmissionDetails(r),
                        icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                        color: AppColors.primary,
                        tooltip: 'View details',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.description, size: 64, color: AppColors.textTertiary),
              const SizedBox(height: 16),
              Text('No requests found', style: AppTextStyles.h3),
              const SizedBox(height: 8),
              Text(
                _searchController.text.isNotEmpty || _statusFilter != 'all'
                    ? 'Try adjusting your filters'
                    : 'Create your first request to get started',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(onPressed: _navigateToUpload, icon: const Icon(Icons.add), label: const Text('Create New Request')),
            ],
          ),
        ),
      ),
    );
  }

  // ─── CHAT PANEL ───────────────────────────────────────────────────────
  Widget _buildChatPanel(DeviceType device) {
    final panelWidth = device == DeviceType.tablet ? 300.0 : 380.0;
    return Container(
      width: panelWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(left: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(-2, 0))],
      ),
      child: _buildChatContent(showClose: true),
    );
  }

  Widget _buildChatDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: SafeArea(child: _buildChatContent(showClose: false)),
    );
  }

  Widget _buildChatContent({bool showClose = false}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AI Assistant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('Ask me anything about your submissions', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
                  ],
                ),
              ),
              if (showClose)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => setState(() => _isChatOpen = false),
                  tooltip: 'Close',
                ),
            ],
          ),
        ),
        Expanded(
          child: _chatMessages.isEmpty
              ? _buildChatEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _chatMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _chatMessages[index];
                    return _buildChatMessage(msg['text'] as String, msg['isUser'] as bool);
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.border))),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  enabled: !_isSendingMessage,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isSendingMessage ? null : _sendMessage,
                icon: _isSendingMessage
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                style: IconButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 56, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text('Start a conversation', style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text('Ask about your submissions, status updates, or any questions',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary), textAlign: TextAlign.center),
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
        child: Text(question, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
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
        child: Text(text, style: AppTextStyles.bodyMedium.copyWith(color: isUser ? Colors.white : AppColors.textPrimary)),
      ),
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────

  /// Granular status badge used in the DataTable — shows exact backend state label
  Widget _buildStatusBadge(String normalizedStatus, String rawState) {
    Color bgColor, textColor;
    String label;

    final state = rawState.toLowerCase();
    switch (state) {
      case 'approved':
        bgColor = const Color(0xFFD1FAE5); textColor = const Color(0xFF065F46); label = 'Approved'; break;
      case 'rejected':
      case 'validationfailed':
        bgColor = const Color(0xFFFEE2E2); textColor = const Color(0xFF991B1B); label = state == 'validationfailed' ? 'Validation Failed' : 'Rejected'; break;
      case 'validated':
      case 'recommending':
      case 'pendingapproval':
      case 'submitted':
        bgColor = const Color(0xFFDBEAFE); textColor = const Color(0xFF1E40AF);
        label = state == 'pendingapproval' ? 'Pending ASM Approval' : state == 'recommending' ? 'Recommending' : state == 'submitted' ? 'Submitted' : 'Validated';
        break;
      case 'reuploadrequested':
        bgColor = const Color(0xFFFEE2E2); textColor = const Color(0xFF991B1B); label = 'Re-upload Requested'; break;
      case 'onhold':
        bgColor = const Color(0xFFF3F4F6); textColor = const Color(0xFF374151); label = 'On Hold'; break;
      default:
        // uploaded, extracting, validating, pending → yellow
        bgColor = const Color(0xFFFEF3C7); textColor = const Color(0xFF92400E);
        label = state == 'uploaded' ? 'Uploaded' : state == 'extracting' ? 'Extracting' : state == 'validating' ? 'Validating' : 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(2)} L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'approved': return 'Approved';
      case 'rejected': return 'Rejected';
      case 'under_review': return 'Under Review';
      default: return 'Pending';
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
    if (['uploaded', 'extracting', 'validating'].contains(state)) return 'pending';
    if (['validated', 'recommending', 'pendingapproval'].contains(state)) return 'under_review';
    if (state == 'approved') return 'approved';
    if (['rejected', 'validationfailed', 'reuploadrequested'].contains(state)) return 'rejected';
    return 'pending';
  }

  void _showSubmissionDetails(Map<String, dynamic> request) {
    final fapNumber = 'FAP-${request['id']?.toString().substring(0, 8).toUpperCase() ?? 'UNKNOWN'}';
    final status = _normalizeStatus(request['state']?.toString() ?? 'pending');
    final poNumber = request['poNumber']?.toString() ?? request['poNo']?.toString() ?? 'N/A';
    final invoiceNumber = request['invoiceNumber']?.toString() ?? request['invoiceNo']?.toString() ?? 'N/A';
    final poAmount = request['poAmount'];
    final invoiceAmount = request['invoiceAmount'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submission Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('FAP Number', fapNumber),
              _buildDetailRow('Status', _getStatusLabel(status)),
              _buildDetailRow('Submitted Date', _formatDate(request['createdAt'])),
              _buildDetailRow('Last Updated', _formatDate(request['updatedAt'])),
              _buildDetailRow('PO Number', poNumber),
              _buildDetailRow('Invoice Number', invoiceNumber),
              if (poAmount != null) _buildDetailRow('PO Amount', '₹${_formatAmount(double.parse(poAmount.toString()))}'),
              if (invoiceAmount != null) _buildDetailRow('Invoice Amount', '₹${_formatAmount(double.parse(invoiceAmount.toString()))}'),
              _buildDetailRow('Documents', '${request['documentCount'] ?? 0} files'),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
        ],
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
      final response = await _dio.post('/chat/message', data: {'message': userMessage},
          options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}));
      if (response.statusCode == 200 && mounted) {
        setState(() => _chatMessages.add({'text': response.data['response'] ?? 'I received your message.', 'isUser': false}));
      }
    } catch (e) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() => _chatMessages.add({'text': _getMockResponse(userMessage), 'isUser': false}));
      }
    } finally {
      if (mounted) setState(() => _isSendingMessage = false);
    }
  }

  String _getMockResponse(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('status') || lower.contains('latest')) {
      return 'You have ${_requests.length} total submissions. ${_stats['pending']} are pending review.';
    } else if (lower.contains('pending')) {
      return 'You currently have ${_stats['pending']} pending requests waiting for review.';
    } else if (lower.contains('approved')) {
      return 'You have ${_stats['approved']} approved submissions this month.';
    } else if (lower.contains('help')) {
      return 'I can help you with:\n• Check submission status\n• View pending requests\n• Get approval statistics\n• Answer questions about your submissions';
    }
    return 'I understand your question. The AI chat service will be available once Azure OpenAI is configured.';
  }
}

// ─── DATA CLASS ───────────────────────────────────────────────────────
class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatData(this.label, this.value, this.icon, this.color);
}
