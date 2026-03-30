import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/failures.dart';
import 'package:dio/dio.dart';

class SapLogsPage extends StatefulWidget {
  final String token;
  const SapLogsPage({super.key, required this.token});

  @override
  State<SapLogsPage> createState() => _SapLogsPageState();
}

class _SapLogsPageState extends State<SapLogsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SAP Logs',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003087)),
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF003087),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF003087),
                indicatorWeight: 3,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'PO Balance Logs'),
                  Tab(text: 'PO Sync from SAP Logs'),
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey.shade200),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _PoBalanceLogsTab(token: widget.token),
              _PoSyncLogsTab(token: widget.token),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── PO Balance Logs Tab ──────────────────────────────────────────────────────
class _PoBalanceLogsTab extends StatefulWidget {
  final String token;
  const _PoBalanceLogsTab({required this.token});

  @override
  State<_PoBalanceLogsTab> createState() => _PoBalanceLogsTabState();
}

class _PoBalanceLogsTabState extends State<_PoBalanceLogsTab>
    with AutomaticKeepAliveClientMixin {
  late final Dio _dio;
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  int _page = 1;
  final int _pageSize = 10;
  int _totalCount = 0;
  int _totalPages = 1;
  String _search = '';
  bool? _successFilter;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      headers: {'Authorization': 'Bearer ${widget.token}'},
    ));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final resp = await _dio.get('/admin/sap-logs/po-balance',
          queryParameters: {
            'pageNumber': _page,
            'pageSize': _pageSize,
            if (_search.isNotEmpty) 'search': _search,
            if (_successFilter != null) 'success': _successFilter,
          });
      if (resp.statusCode == 200 && mounted) {
        final data = resp.data as Map<String, dynamic>;
        setState(() {
          _items = List<Map<String, dynamic>>.from(data['items'] as List);
          _totalCount = data['totalCount'] as int;
          _totalPages = data['totalPages'] as int? ?? 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.show(context, failure: ServerFailure(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filters
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _statusFilter(),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search PO number or company...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    _search = v;
                    _page = 1;
                    _load();
                  },
                ),
              ),
              IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF003087)),
                  tooltip: 'Refresh',
                  onPressed: _load),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Text('No PO balance logs found.',
                            style: TextStyle(color: Colors.grey.shade500)))
                    : _buildTable(),
          ),
          const SizedBox(height: 12),
          _pagination(),
        ],
      ),
    );
  }

  Widget _statusFilter() => Container(
        width: 150,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<bool?>(
            value: _successFilter,
            isDense: true,
            hint: const Text('All Status',
                style: TextStyle(fontSize: 13)),
            items: const [
              DropdownMenuItem(
                  value: null,
                  child: Text('All Status',
                      style: TextStyle(fontSize: 13))),
              DropdownMenuItem(
                  value: true,
                  child: Text('Success',
                      style: TextStyle(fontSize: 13))),
              DropdownMenuItem(
                  value: false,
                  child: Text('Failed',
                      style: TextStyle(fontSize: 13))),
            ],
            onChanged: (v) {
              setState(() {
                _successFilter = v;
                _page = 1;
              });
              _load();
            },
          ),
        ),
      );

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
            headingRowColor:
                WidgetStateProperty.all(const Color(0xFFF0F4FF)),
            headingTextStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF003087),
                fontSize: 13),
            dataRowMinHeight: 52,
            dataRowMaxHeight: 52,
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('PO Number')),
              DataColumn(label: Text('Company Code')),
              DataColumn(label: Text('Balance')),
              DataColumn(label: Text('SAP Status')),
              DataColumn(label: Text('Result')),
              DataColumn(label: Text('Elapsed (ms)')),
              DataColumn(label: Text('Error')),
              DataColumn(label: Text('Requested On')),
            ],
            rows: _items.map((item) {
              final success = item['isSuccess'] as bool? ?? false;
              final balance = item['balance'];
              final currency = item['currency'] as String? ?? '';
              final sapStatus = item['sapHttpStatus'];
              final elapsed = item['elapsedMs'] ?? 0;
              final error = item['errorMessage'] as String?;
              return DataRow(cells: [
                DataCell(Text(item['poNum'] ?? '—',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500))),
                DataCell(Text(item['companyCode'] ?? '—',
                    style: const TextStyle(fontSize: 13))),
                DataCell(Text(
                  balance != null
                      ? '$currency ${balance.toString()}'
                      : '—',
                  style: const TextStyle(fontSize: 13),
                )),
                DataCell(Text(
                  sapStatus?.toString() ?? '—',
                  style: TextStyle(
                      fontSize: 13,
                      color: sapStatus == 200
                          ? Colors.green.shade700
                          : Colors.red.shade700),
                )),
                DataCell(_ResultBadge(success: success)),
                DataCell(Text('$elapsed ms',
                    style: const TextStyle(fontSize: 13))),
                DataCell(SizedBox(
                  width: 180,
                  child: Text(error ?? '—',
                      style: TextStyle(
                          fontSize: 12,
                          color: error != null
                              ? Colors.red.shade700
                              : Colors.grey),
                      overflow: TextOverflow.ellipsis),
                )),
                DataCell(Text(_fmtDate(item['requestedAt'] as String?),
                    style: const TextStyle(fontSize: 13))),
              ]);
            }).toList(),
          ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pagination() => Row(children: [
        Text('Showing ${_items.length} of $_totalCount entries',
            style:
                TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _page > 1
              ? () {
                  setState(() => _page--);
                  _load();
                }
              : null,
        ),
        Text('$_page / $_totalPages',
            style: const TextStyle(fontSize: 13)),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _page < _totalPages
              ? () {
                  setState(() => _page++);
                  _load();
                }
              : null,
        ),
      ]);

  String _fmtDate(String? d) {
    if (d == null || d.isEmpty) return '—';
    return d.length >= 16
        ? d.substring(0, 16).replaceAll('T', ' ')
        : d;
  }
}

// ─── PO Sync Logs Tab ─────────────────────────────────────────────────────────
class _PoSyncLogsTab extends StatefulWidget {
  final String token;
  const _PoSyncLogsTab({required this.token});

  @override
  State<_PoSyncLogsTab> createState() => _PoSyncLogsTabState();
}

class _PoSyncLogsTabState extends State<_PoSyncLogsTab>
    with AutomaticKeepAliveClientMixin {
  late final Dio _dio;
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  int _page = 1;
  final int _pageSize = 10;
  int _totalCount = 0;
  int _totalPages = 1;
  String _search = '';
  String? _statusFilter;

  static const _statuses = [
    'Success',
    'Failed',
    'AgencyNotFound',
    'POAlreadyExists',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      headers: {'Authorization': 'Bearer ${widget.token}'},
    ));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final resp = await _dio.get('/admin/sap-logs/po-sync',
          queryParameters: {
            'pageNumber': _page,
            'pageSize': _pageSize,
            if (_search.isNotEmpty) 'search': _search,
            if (_statusFilter != null) 'status': _statusFilter,
          });
      if (resp.statusCode == 200 && mounted) {
        final data = resp.data as Map<String, dynamic>;
        setState(() {
          _items = List<Map<String, dynamic>>.from(data['items'] as List);
          _totalCount = data['totalCount'] as int;
          _totalPages = data['totalPages'] as int? ?? 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.show(context, failure: ServerFailure(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _statusDropdown(),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search file name...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    _search = v;
                    _page = 1;
                    _load();
                  },
                ),
              ),
              IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF003087)),
                  tooltip: 'Refresh',
                  onPressed: _load),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Text('No PO sync logs found.',
                            style: TextStyle(color: Colors.grey.shade500)))
                    : _buildTable(),
          ),
          const SizedBox(height: 12),
          _pagination(),
        ],
      ),
    );
  }

  Widget _statusDropdown() => Container(
        width: 180,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: _statusFilter,
            isDense: true,
            hint: const Text('All Statuses',
                style: TextStyle(fontSize: 13)),
            items: [
              const DropdownMenuItem(
                  value: null,
                  child: Text('All Statuses',
                      style: TextStyle(fontSize: 13))),
              ..._statuses.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s,
                      style: const TextStyle(fontSize: 13)))),
            ],
            onChanged: (v) {
              setState(() {
                _statusFilter = v;
                _page = 1;
              });
              _load();
            },
          ),
        ),
      );

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
            headingRowColor:
                WidgetStateProperty.all(const Color(0xFFF0F4FF)),
            headingTextStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF003087),
                fontSize: 13),
            dataRowMinHeight: 52,
            dataRowMaxHeight: 52,
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('File Name')),
              DataColumn(label: Text('Source')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Agency ID')),
              DataColumn(label: Text('PO ID')),
              DataColumn(label: Text('Error')),
              DataColumn(label: Text('Processed On')),
            ],
            rows: _items.map((item) {
              final status = item['status'] as String? ?? '—';
              final error = item['errorMessage'] as String?;
              final agencyId = item['agencyId']?.toString();
              final poId = item['pOId']?.toString() ?? item['poId']?.toString();
              return DataRow(cells: [
                DataCell(SizedBox(
                  width: 200,
                  child: Text(item['fileName'] ?? '—',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                )),
                DataCell(Text(item['sourceSystem'] ?? 'SAP',
                    style: const TextStyle(fontSize: 13))),
                DataCell(_SyncStatusBadge(status: status)),
                DataCell(Text(
                  agencyId != null
                      ? agencyId.substring(0, 8) + '...'
                      : '—',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                )),
                DataCell(Text(
                  poId != null ? poId.substring(0, 8) + '...' : '—',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                )),
                DataCell(SizedBox(
                  width: 180,
                  child: Text(error ?? '—',
                      style: TextStyle(
                          fontSize: 12,
                          color: error != null
                              ? Colors.red.shade700
                              : Colors.grey),
                      overflow: TextOverflow.ellipsis),
                )),
                DataCell(Text(
                    _fmtDate(item['processedAt'] as String?),
                    style: const TextStyle(fontSize: 13))),
              ]);
            }).toList(),
          ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pagination() => Row(children: [
        Text('Showing ${_items.length} of $_totalCount entries',
            style:
                TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _page > 1
              ? () {
                  setState(() => _page--);
                  _load();
                }
              : null,
        ),
        Text('$_page / $_totalPages',
            style: const TextStyle(fontSize: 13)),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _page < _totalPages
              ? () {
                  setState(() => _page++);
                  _load();
                }
              : null,
        ),
      ]);

  String _fmtDate(String? d) {
    if (d == null || d.isEmpty) return '—';
    return d.length >= 16
        ? d.substring(0, 16).replaceAll('T', ' ')
        : d;
  }
}

// ─── Badges ───────────────────────────────────────────────────────────────────
class _ResultBadge extends StatelessWidget {
  final bool success;
  const _ResultBadge({required this.success});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: success
              ? const Color(0xFFD1FAE5)
              : const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          success ? 'Success' : 'Failed',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: success
                ? const Color(0xFF065F46)
                : const Color(0xFFDC2626),
          ),
        ),
      );
}

class _SyncStatusBadge extends StatelessWidget {
  final String status;
  const _SyncStatusBadge({required this.status});

  Color get _bg {
    switch (status) {
      case 'Success':        return const Color(0xFFD1FAE5);
      case 'Failed':         return const Color(0xFFFEE2E2);
      case 'AgencyNotFound': return const Color(0xFFFEF3C7);
      case 'POAlreadyExists':return const Color(0xFFEFF6FF);
      default:               return Colors.grey.shade100;
    }
  }

  Color get _fg {
    switch (status) {
      case 'Success':        return const Color(0xFF065F46);
      case 'Failed':         return const Color(0xFFDC2626);
      case 'AgencyNotFound': return const Color(0xFF92400E);
      case 'POAlreadyExists':return const Color(0xFF1D4ED8);
      default:               return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(status,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _fg)),
      );
}
