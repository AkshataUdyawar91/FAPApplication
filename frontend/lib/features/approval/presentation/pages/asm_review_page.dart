import 'package:pretty_dio_logger/pretty_dio_logger.dart';
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
  final _dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'))..interceptors.add(PrettyDioLogger());
  final _searchController = TextEditingController();

  String _statusFilter = 'all';
  String _sortBy = 'date';
  bool _sortAscending = false;
  bool _isLoading = true;
  bool _isChatOpen = false;
  bool _isSidebarCollapsed = true;
  List<Map<String, dynamic>> _documents = [];

  // KPI state
  String _selectedQuarter = 'Q${(DateTime.now().month - 1) ~/ 3 + 1}';
  int _selectedYear = DateTime.now().year;
  QuarterlyFapKpiModel? _kpiData;
  bool _isKpiLoading = true;
  String? _kpiError;

  String _normalizeStatus(String backendState) {
    final state = backendState.toLowerCase().replaceAll('_', '');
    // ASM role status normalization
    if (state == 'pendingasmapproval' || state == 'pendingapproval' || state == 'pendingwithasm') return 'pending';
    if (state == 'pendinghqapproval' || state == 'pendingwithra') return 'pending-with-ra';
    if (state == 'approved') return 'approved';
    if (state == 'rejectedbyasm' || state == 'rejected') return 'rejected';
    if (state == 'rejectedbyhq' || state == 'rejectedbyra') return 'rejected-by-ra';
    if (state == 'validationfailed' || state == 'reuploadrequested') return 'rejected';
    if (state == 'uploaded' || state == 'extracting' || state == 'validating' ||
        state == 'scoring' || state == 'recommending') {
      return 'processing';
    }
    return 'processing';
  }



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

  /// Returns the start and end months (1-indexed) for a quarter string.
  /// Q1 = Jan-Mar, Q2 = Apr-Jun, Q3 = Jul-Sep, Q4 = Oct-Dec.
  (int, int) _quarterMonthRange(String quarter) {
    switch (quarter) {
      case 'Q1': return (1, 3);
      case 'Q2': return (4, 6);
      case 'Q3': return (7, 9);
      case 'Q4': return (10, 12);
      default: return (1, 12);
    }
  }

  bool _matchesQuarterYear(Map<String, dynamic> doc) {
    final dateStr = doc['createdAt']?.toString();
    if (dateStr == null) return false;
    try {
      final dt = DateTime.parse(dateStr);
      if (dt.year != _selectedYear) return false;
      if (_selectedQuarter == 'All') return true;
      final (startMonth, endMonth) = _quarterMonthRange(_selectedQuarter);
      return dt.month >= startMonth && dt.month <= endMonth;
    } catch (_) {
      return false;
    }
  }

  List<Map<String, dynamic>> get _filteredDocuments {
    final filtered = _documents.where((doc) {
      final status = _normalizeStatus(doc['state']?.toString() ?? '');
      if (status == 'processing') return false;
      if (!_matchesQuarterYear(doc)) return false;
      final matchesSearch = _searchController.text.isEmpty ||
          doc['id']?.toString().toLowerCase().contains(_searchController.text.toLowerCase()) == true ||
          doc['invoiceNumber']?.toString().toLowerCase().contains(_searchController.text.toLowerCase()) == true ||
          doc['poNumber']?.toString().toLowerCase().contains(_searchController.text.toLowerCase()) == true;
      final matchesStatus = _statusFilter == 'all' || status == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();

    filtered.sort((a, b) {
      int result;
      switch (_sortBy) {
        case 'amount':
          final aAmt = double.tryParse(a['poAmount']?.toString() ?? '') ?? 0;
          final bAmt = double.tryParse(b['poAmount']?.toString() ?? '') ?? 0;
          result = aAmt.compareTo(bAmt);
          break;
        case 'invoiceNo':
          final aInv = a['invoiceNumber']?.toString() ?? '';
          final bInv = b['invoiceNumber']?.toString() ?? '';
          result = aInv.compareTo(bInv);
          break;
        case 'poNo':
          final aPo = a['poNumber']?.toString() ?? '';
          final bPo = b['poNumber']?.toString() ?? '';
          result = aPo.compareTo(bPo);
          break;
        case 'status':
          final aStatus = _normalizeStatus(a['state']?.toString() ?? '');
          final bStatus = _normalizeStatus(b['state']?.toString() ?? '');
          result = aStatus.compareTo(bStatus);
          break;
        case 'date':
        default:
          final aDate = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(2000);
          final bDate = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(2000);
          result = aDate.compareTo(bDate);
      }
      return _sortAscending ? result : -result;
    });

    return filtered;
  }

  List<NavItem> _getNavItems(BuildContext context) {
    return [
      NavItem(icon: Icons.dashboard, label: 'Dashboard', isActive: true, onTap: () {}),
      NavItem(icon: Icons.notifications, label: 'Notifications', onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications coming soon')));
      },),
      NavItem(icon: Icons.settings, label: 'Settings', onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings coming soon')));
      },),
    ];
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
                  title: const Text('ASM Review', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  iconTheme: const IconThemeData(color: Colors.white),
                  actions: const [],
                )
              : null,
          drawer: isMobile ? AppDrawer(
            userName: widget.userName,
            userRole: 'ASM',
            navItems: _getNavItems(context),
            onLogout: () => Navigator.pushReplacementNamed(context, '/'),
          ) : null,
          body: Column(
            children: [
              if (!isMobile) _buildTopBar(),
              Expanded(
                child: Row(
                  children: [
                    if (!isMobile) AppSidebar(
                      userName: widget.userName,
                      userRole: 'ASM',
                      navItems: _getNavItems(context),
                      onLogout: () => Navigator.pushReplacementNamed(context, '/'),
                      isCollapsed: _isSidebarCollapsed,
                      onToggleCollapse: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
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
                      userName: widget.userName,
                      deviceType: device,
                      onClose: () => setState(() => _isChatOpen = false),
                    ),
                  ],
                ),
              ),
            ],
          ),
          endDrawer: isMobile ? ChatEndDrawer(token: widget.token, userName: widget.userName) : null,
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
              Text('ASM', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
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
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ASM Review', style: AppTextStyles.h2),
                SizedBox(height: 4),
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
              const Text('ASM Review', style: AppTextStyles.h2),
              const SizedBox(height: 4),
              const Text('Review and approve agency submissions', style: AppTextStyles.bodySmall),
              const SizedBox(height: 16),
            ],
            _buildKpiSection(),
            const SizedBox(height: 24),
            _buildSearchBar(),
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
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 700;
                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quarterly FAP KPIs', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
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
                          _buildCompactStatusDropdown(),
                          _buildCompactSortDropdown(),
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Text('Quarterly FAP KPIs', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    _buildCompactStatusDropdown(),
                    const SizedBox(width: 12),
                    _buildCompactSortDropdown(),
                    const SizedBox(width: 12),
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
                );
              },
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
                  ),).toList(),);
                },
              ),
          ],
        ),
      ),
    );
  }



  Widget _buildCompactStatusDropdown() {
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<String>(
        key: ValueKey('status_$_statusFilter'),
        initialValue: _statusFilter,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Status',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
        ),
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All')),
          DropdownMenuItem(value: 'pending', child: Text('Pending')),
          DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
          DropdownMenuItem(value: 'rejected-by-ra', child: Text('Rejected by RA')),
          DropdownMenuItem(value: 'pending-with-ra', child: Text('Pending with RA')),
          DropdownMenuItem(value: 'approved', child: Text('Approved')),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _statusFilter = value);
        },
      ),
    );
  }

  Widget _buildCompactSortDropdown() {
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<String>(
        key: ValueKey('sort_$_sortBy'),
        initialValue: _sortBy,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Sort by',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
        ),
        items: const [
          DropdownMenuItem(value: 'date', child: Text('Date')),
          DropdownMenuItem(value: 'amount', child: Text('Amount')),
          DropdownMenuItem(value: 'poNo', child: Text('PO No.')),
          DropdownMenuItem(value: 'invoiceNo', child: Text('Invoice No.')),
          DropdownMenuItem(value: 'status', child: Text('Status')),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() {
              if (_sortBy == value) {
                _sortAscending = !_sortAscending;
              } else {
                _sortBy = value;
                _sortAscending = false;
              }
            });
          }
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search by agency name or document ID...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onChanged: (_) => setState(() {}),
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
    final invoiceNumber = doc['invoiceNumber']?.toString() ?? '-';
    final invoiceAmount = doc['invoiceAmount'];
    final invoiceAmountStr = invoiceAmount != null ? '₹${double.parse(invoiceAmount.toString()).toStringAsFixed(2)}' : '-';

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
              ],),
              const SizedBox(height: 12),
              _buildInfoRow('PO Number', poNumber),
              _buildInfoRow('Invoice Number', invoiceNumber),
              _buildInfoRow('Invoice Amount', invoiceAmountStr),
              _buildInfoRow('Submitted', _formatDate(doc['createdAt'])),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToDetail(doc['id']),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('View Details'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        Text(value, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
      ],),
    );
  }

  void _navigateToDetail(dynamic id) async {
    final result = await Navigator.pushNamed(context, '/asm/review-detail', arguments: {
      'submissionId': id,
      'token': widget.token,
      'userName': widget.userName,
    },);
    if (result == true || result == null) _loadDocuments();
  }

  int? get _sortColumnIndex {
    switch (_sortBy) {
      case 'poNo': return 1;
      case 'invoiceNo': return 2;
      case 'amount': return 3;
      case 'date': return 4;
      case 'status': return 5;
      default: return null;
    }
  }

  void _onColumnSort(String column, bool ascending) {
    setState(() {
      _sortBy = column;
      _sortAscending = ascending;
    });
  }

  Widget _buildDesktopTable(List<Map<String, dynamic>> filtered) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width * 0.95),
            child: DataTable(
              sortColumnIndex: _sortColumnIndex,
              sortAscending: _sortAscending,
              headingRowColor: WidgetStateProperty.all(AppColors.background),
              headingTextStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.3),
              dataTextStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              columnSpacing: 16,
              horizontalMargin: 24,
              dataRowMinHeight: 56,
              dataRowMaxHeight: 72,
              dividerThickness: 1,
              columns: [
                const DataColumn(label: Text('FAP NUMBER')),
                DataColumn(label: const Text('PO NO.'), onSort: (_, asc) => _onColumnSort('poNo', asc)),
                DataColumn(label: const Text('INVOICE NO.'), onSort: (_, asc) => _onColumnSort('invoiceNo', asc)),
                DataColumn(label: const Text('INVOICE AMT'), onSort: (_, asc) => _onColumnSort('amount', asc)),
                DataColumn(label: const Text('SUBMITTED DATE'), onSort: (_, asc) => _onColumnSort('date', asc)),
                DataColumn(label: const Text('STATUS'), onSort: (_, asc) => _onColumnSort('status', asc)),
                const DataColumn(label: SizedBox.shrink()),
              ],
              rows: filtered.map((doc) => _buildDocumentDataRow(doc)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _buildDocumentDataRow(Map<String, dynamic> doc) {
    final status = _normalizeStatus(doc['state']?.toString() ?? '');
    final fapNumber = 'FAP-${doc['id']?.toString().substring(0, 8).toUpperCase() ?? 'UNKNOWN'}';
    final poNumber = doc['poNumber']?.toString() ?? '-';
    final invoiceNumber = doc['invoiceNumber']?.toString() ?? '-';
    final invoiceAmount = doc['invoiceAmount'];
    final invoiceAmountStr = invoiceAmount != null ? '₹${double.parse(invoiceAmount.toString()).toStringAsFixed(2)}' : '-';

    return DataRow(cells: [
      DataCell(Text(fapNumber, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF111827)))),
      DataCell(Text(poNumber)),
      DataCell(Text(invoiceNumber)),
      DataCell(Text(invoiceAmountStr, style: const TextStyle(fontWeight: FontWeight.w600))),
      DataCell(Text(_formatDate(doc['createdAt']))),
      DataCell(_buildStatusBadge(status)),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.visibility_outlined, size: 20),
            color: AppColors.primary,
            onPressed: () => _navigateToDetail(doc['id']),
            tooltip: 'View Details',
          ),
        ],
      ),),
    ],);
  }

  Widget _buildStatusBadge(String? status) {
    Color bgColor, textColor, borderColor;
    String label;
    // ASM role status labels
    switch (status) {
      case 'pending':
        bgColor = AppColors.pendingBackground; textColor = AppColors.pendingText; borderColor = AppColors.pendingBorder; label = 'Pending'; break;
      case 'pending-with-ra':
        bgColor = const Color(0xFFFEF3C7); textColor = const Color(0xFF92400E); borderColor = const Color(0xFFF59E0B); label = 'Pending with RA'; break;
      case 'approved':
        bgColor = AppColors.approvedBackground; textColor = AppColors.approvedText; borderColor = AppColors.approvedBorder; label = 'Approved'; break;
      case 'rejected':
        bgColor = AppColors.rejectedBackground; textColor = AppColors.rejectedText; borderColor = AppColors.rejectedBorder; label = 'Rejected'; break;
      case 'rejected-by-ra':
        bgColor = AppColors.rejectedBackground; textColor = AppColors.rejectedText; borderColor = AppColors.rejectedBorder; label = 'Rejected by RA'; break;
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

