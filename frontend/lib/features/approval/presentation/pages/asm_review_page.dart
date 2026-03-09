import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/widgets/app_sidebar.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../core/widgets/chat_side_panel.dart';
import '../../../../core/widgets/chat_end_drawer.dart';
import '../../../../core/widgets/nav_item.dart';
import '../../../../core/widgets/kpi_card.dart';
import '../../../../core/widgets/quarter_year_filter.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../analytics/data/models/quarterly_fap_kpi_model.dart';

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
  bool _isChatOpen = true;
  List<Map<String, dynamic>> _documents = [];

  // KPI state
  String _selectedQuarter = 'Q${(DateTime.now().month - 1) ~/ 3 + 1}';
  int _selectedYear = DateTime.now().year;
  QuarterlyFapKpiModel? _kpiData;
  bool _isKpiLoading = true;
  String? _kpiError;

  String _normalizeStatus(String backendState) {
    final state = backendState.toLowerCase().replaceAll('_', '');
    if (state == 'pendingasmapproval' || state == 'pendingapproval') return 'asm-review';
    if (state == 'pendinghqapproval') return 'with-hq';
    if (state == 'approved') return 'approved';
    if (state == 'rejectedbyasm' || state == 'rejected' || state == 'rejectedbyhq' ||
        state == 'validationfailed' || state == 'reuploadrequested') return 'rejected';
    if (state == 'uploaded' || state == 'extracting' || state == 'validating' ||
        state == 'scoring' || state == 'recommending') return 'processing';
    return 'processing';
  }

  int get _pendingCount => _documents.where((d) {
    final state = d['state']?.toString().toLowerCase() ?? '';
    return state == 'pendingasmapproval' || state == 'pendingapproval' || state == 'rejectedbyhq';
  }).length;

  int get _approvedCount => _documents.where((d) {
    final state = d['state']?.toString().toLowerCase() ?? '';
    return state == 'approved';
  }).length;

  int get _rejectedCount => _documents.where((d) {
    final state = d['state']?.toString().toLowerCase() ?? '';
    return state == 'rejectedbyasm' || state == 'rejected' || state == 'validationfailed' || state == 'reuploadrequested';
  }).length;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
    _loadKpiData();
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
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load submissions: $e'), backgroundColor: AppColors.rejectedText),
        );
      }
    }
  }

  Future<void> _loadKpiData() async {
    setState(() {
      _isKpiLoading = true;
      _kpiError = null;
    });
    try {
      final response = await _dio.get(
        '/analytics/quarterly-fap',
        queryParameters: {'quarter': _selectedQuarter, 'year': _selectedYear},
        options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _kpiData = QuarterlyFapKpiModel.fromJson(response.data as Map<String, dynamic>);
          _isKpiLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isKpiLoading = false;
          _kpiError = 'Failed to load KPI data';
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredDocuments {
    return _documents.where((doc) {
      final status = _normalizeStatus(doc['state']?.toString() ?? '');
      if (status == 'processing') return false;
      final matchesSearch = _searchController.text.isEmpty ||
          doc['id']?.toString().toLowerCase().contains(_searchController.text.toLowerCase()) == true ||
          doc['invoiceNumber']?.toString().toLowerCase().contains(_searchController.text.toLowerCase()) == true ||
          doc['poNumber']?.toString().toLowerCase().contains(_searchController.text.toLowerCase()) == true;
      final matchesStatus = _statusFilter == 'all' || status == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  List<NavItem> _getNavItems(BuildContext context) {
    return [
      NavItem(icon: Icons.dashboard, label: 'Dashboard', isActive: true, onTap: () {}),
      NavItem(icon: Icons.notifications, label: 'Notifications', onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications coming soon')));
      }),
      NavItem(icon: Icons.settings, label: 'Settings', onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings coming soon')));
      }),
    ];
  }

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
                  title: const Text('ASM Review', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  iconTheme: const IconThemeData(color: Colors.white),
                )
              : null,
          drawer: isMobile ? AppDrawer(
            userName: widget.userName,
            userRole: 'ASM',
            navItems: _getNavItems(context),
            onLogout: () => Navigator.pushReplacementNamed(context, '/'),
          ) : null,
          body: Row(
            children: [
              if (!isMobile) AppSidebar(
                userName: widget.userName,
                userRole: 'ASM',
                navItems: _getNavItems(context),
                onLogout: () => Navigator.pushReplacementNamed(context, '/'),
                isCollapsed: isTablet,
              ),
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
              if (_isChatOpen && !isMobile) ChatSidePanel(
                token: widget.token,
                deviceType: device,
                onClose: () => setState(() => _isChatOpen = false),
              ),
            ],
          ),
          endDrawer: isMobile ? ChatEndDrawer(token: widget.token) : null,
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
                child: const Icon(Icons.smart_toy, color: Colors.white),
              ),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }

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
                Text('ASM Review', style: AppTextStyles.h2),
                const SizedBox(height: 4),
                Text('Review and approve agency submissions', style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(DeviceType device) {
    final hPad = responsiveValue<double>(MediaQuery.of(context).size.width, mobile: 12, tablet: 16, desktop: 24);
    return RefreshIndicator(
      onRefresh: _loadDocuments,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(hPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (device == DeviceType.mobile) ...[
              Text('ASM Review', style: AppTextStyles.h2),
              const SizedBox(height: 4),
              Text('Review and approve agency submissions', style: AppTextStyles.bodySmall),
              const SizedBox(height: 16),
            ],
            _buildStatsCards(),
            const SizedBox(height: 24),
            _buildKpiSection(),
            const SizedBox(height: 24),
            _buildFilters(),
            const SizedBox(height: 24),
            _buildDocumentsList(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Quarterly FAP KPIs', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                QuarterYearFilter(
                  selectedQuarter: _selectedQuarter,
                  selectedYear: _selectedYear,
                  availableYears: List.generate(5, (i) => DateTime.now().year - i),
                  onQuarterChanged: (q) {
                    setState(() => _selectedQuarter = q);
                    _loadKpiData();
                  },
                  onYearChanged: (y) {
                    setState(() => _selectedYear = y);
                    _loadKpiData();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_kpiError != null)
              Center(
                child: Column(
                  children: [
                    Text(_kpiError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.rejectedText)),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _loadKpiData,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 500;
                  final cards = [
                    KpiCard(
                      label: 'FAP Amount',
                      value: _isKpiLoading ? '' : formatIndianCurrency(_kpiData?.fapAmount ?? 0),
                      icon: Icons.currency_rupee,
                      color: const Color(0xFF10B981),
                      isLoading: _isKpiLoading,
                    ),
                    KpiCard(
                      label: 'FAP Count',
                      value: _isKpiLoading ? '' : '${_kpiData?.fapCount ?? 0}',
                      icon: Icons.receipt_long,
                      color: const Color(0xFF3B82F6),
                      isLoading: _isKpiLoading,
                    ),
                  ];
                  if (isMobile) {
                    return Column(children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList());
                  }
                  return Row(children: cards.asMap().entries.map((e) => Expanded(
                    child: Padding(padding: EdgeInsets.only(right: e.key == 0 ? 16 : 0), child: e.value),
                  )).toList());
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final cards = [
          _StatCardData('Pending Review', _pendingCount.toString(), Icons.schedule, const Color(0xFFF59E0B)),
          _StatCardData('Approved', _approvedCount.toString(), Icons.check_circle, const Color(0xFF10B981)),
          _StatCardData('Rejected', _rejectedCount.toString(), Icons.cancel, const Color(0xFFEF4444)),
        ];
        if (isMobile) {
          return Column(children: cards.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildStatCard(c.label, c.value, c.icon, c.color),
          )).toList());
        }
        return Row(children: cards.map((c) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: c == cards.last ? 0 : 16),
            child: _buildStatCard(c.label, c.value, c.icon, c.color),
          ),
        )).toList());
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
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
                children: [
                  Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(value, style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    ? Column(children: [
                        DropdownButtonFormField<String>(
                          value: _statusFilter,
                          decoration: const InputDecoration(labelText: 'Filter by status', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Status')),
                            DropdownMenuItem(value: 'asm-review', child: Text('Pending Review')),
                            DropdownMenuItem(value: 'with-hq', child: Text('With HQ/RA')),
                            DropdownMenuItem(value: 'approved', child: Text('Approved')),
                            DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                          ],
                          onChanged: (value) => setState(() => _statusFilter = value!),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _sortBy,
                          decoration: const InputDecoration(labelText: 'Sort by', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'date', child: Text('Date')),
                            DropdownMenuItem(value: 'amount', child: Text('Amount')),
                            DropdownMenuItem(value: 'confidence', child: Text('Confidence')),
                          ],
                          onChanged: (value) => setState(() => _sortBy = value!),
                        ),
                      ])
                    : Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _statusFilter,
                            decoration: const InputDecoration(labelText: 'Filter by status', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All Status')),
                              DropdownMenuItem(value: 'asm-review', child: Text('Pending Review')),
                              DropdownMenuItem(value: 'with-hq', child: Text('With HQ/RA')),
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
                            decoration: const InputDecoration(labelText: 'Sort by', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'date', child: Text('Date')),
                              DropdownMenuItem(value: 'amount', child: Text('Amount')),
                              DropdownMenuItem(value: 'confidence', child: Text('Confidence')),
                            ],
                            onChanged: (value) => setState(() => _sortBy = value!),
                          ),
                        ),
                      ]),
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
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Center(child: Text('No documents found matching your criteria.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary))),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(children: filtered.map((doc) => _buildMobileDocumentCard(doc)).toList());
        }
        return _buildDesktopTable(filtered);
      },
    );
  }

  Widget _buildMobileDocumentCard(Map<String, dynamic> doc) {
    final status = _normalizeStatus(doc['state']?.toString() ?? '');
    final fapNumber = 'FAP-${doc['id']?.toString().substring(0, 8).toUpperCase() ?? 'UNKNOWN'}';
    final poNumber = doc['poNumber']?.toString() ?? '-';
    final poAmount = doc['poAmount'];
    final invoiceNumber = doc['invoiceNumber']?.toString() ?? '-';
    final invoiceAmount = doc['invoiceAmount'];
    final poAmountStr = poAmount != null ? '₹${double.parse(poAmount.toString()).toStringAsFixed(2)}' : '-';
    final invoiceAmountStr = invoiceAmount != null ? '₹${double.parse(invoiceAmount.toString()).toStringAsFixed(2)}' : '-';
    final overallConfidence = doc['overallConfidence'];
    final aiScore = overallConfidence != null ? '${(overallConfidence * 100).toStringAsFixed(0)}%' : '-';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToDetail(doc['id']),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(fapNumber, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary)),
                _buildStatusBadge(status),
              ]),
              const SizedBox(height: 12),
              _buildInfoRow('PO Number', poNumber),
              _buildInfoRow('PO Amount', poAmountStr),
              _buildInfoRow('Invoice Number', invoiceNumber),
              _buildInfoRow('Invoice Amount', invoiceAmountStr),
              _buildInfoRow('Submitted', _formatDate(doc['createdAt'])),
              _buildInfoRow('AI Score', aiScore),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToDetail(doc['id']),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('View Details'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        Text(value, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
      ]),
    );
  }

  void _navigateToDetail(dynamic id) async {
    final result = await Navigator.pushNamed(context, '/asm/review-detail', arguments: {
      'submissionId': id,
      'token': widget.token,
      'userName': widget.userName,
    });
    if (result == true || result == null) _loadDocuments();
  }

  Widget _buildDesktopTable(List<Map<String, dynamic>> filtered) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          constraints: const BoxConstraints(minWidth: 1200),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
                ),
                child: Row(children: [
                  _headerCell('FAP NUMBER', 140),
                  _headerCell('PO NO.', 120),
                  _headerCell('PO AMT', 140),
                  _headerCell('INVOICE NO.', 160),
                  _headerCell('INVOICE AMT', 140),
                  _headerCell('SUBMITTED DATE', 140),
                  _headerCell('AI SCORE', 100),
                  _headerCell('STATUS', 140),
                  const SizedBox(width: 80),
                ]),
              ),
              ...filtered.map((doc) => _buildDocumentRow(doc)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(text, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
    );
  }

  Widget _buildDocumentRow(Map<String, dynamic> doc) {
    final status = _normalizeStatus(doc['state']?.toString() ?? '');
    final fapNumber = 'FAP-${doc['id']?.toString().substring(0, 8).toUpperCase() ?? 'UNKNOWN'}';
    final poNumber = doc['poNumber']?.toString() ?? '-';
    final poAmount = doc['poAmount'];
    final invoiceNumber = doc['invoiceNumber']?.toString() ?? '-';
    final invoiceAmount = doc['invoiceAmount'];
    final poAmountStr = poAmount != null ? '₹${double.parse(poAmount.toString()).toStringAsFixed(2)}' : '-';
    final invoiceAmountStr = invoiceAmount != null ? '₹${double.parse(invoiceAmount.toString()).toStringAsFixed(2)}' : '-';
    final overallConfidence = doc['overallConfidence'];
    final aiScore = overallConfidence != null ? '${(overallConfidence * 100).toStringAsFixed(0)}%' : '-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 1))),
      child: Row(children: [
        SizedBox(width: 140, child: Text(fapNumber, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500))),
        SizedBox(width: 120, child: Text(poNumber, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary))),
        SizedBox(width: 140, child: Text(poAmountStr, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
        SizedBox(width: 160, child: Text(invoiceNumber, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary))),
        SizedBox(width: 140, child: Text(invoiceAmountStr, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
        SizedBox(width: 140, child: Text(_formatDate(doc['createdAt']), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary))),
        SizedBox(width: 100, child: Text(aiScore, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
        SizedBox(width: 140, child: _buildStatusBadge(status)),
        SizedBox(width: 80, child: IconButton(
          icon: const Icon(Icons.visibility_outlined, size: 20),
          color: AppColors.primary,
          onPressed: () => _navigateToDetail(doc['id']),
          tooltip: 'View Details',
        )),
      ]),
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color bgColor, textColor, borderColor;
    String label;
    switch (status) {
      case 'asm-review':
        bgColor = AppColors.pendingBackground; textColor = AppColors.pendingText; borderColor = AppColors.pendingBorder; label = 'Pending Review'; break;
      case 'approved':
        bgColor = AppColors.approvedBackground; textColor = AppColors.approvedText; borderColor = AppColors.approvedBorder; label = 'Approved'; break;
      case 'rejected':
        bgColor = AppColors.rejectedBackground; textColor = AppColors.rejectedText; borderColor = AppColors.rejectedBorder; label = 'Rejected'; break;
      default:
        bgColor = AppColors.reviewBackground; textColor = AppColors.reviewText; borderColor = AppColors.reviewBorder; label = status ?? 'Unknown';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bgColor, border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: AppTextStyles.bodySmall.copyWith(color: textColor, fontWeight: FontWeight.w600)),
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

class _StatCardData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCardData(this.label, this.value, this.icon, this.color);
}
