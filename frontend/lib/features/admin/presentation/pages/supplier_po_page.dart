import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class SupplierPoPage extends StatefulWidget {
  final String token;
  const SupplierPoPage({super.key, required this.token});

  @override
  State<SupplierPoPage> createState() => _SupplierPoPageState();
}

class _SupplierPoPageState extends State<SupplierPoPage> {
  late final Dio _dio;
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _pos = [];
  bool _isLoading = true;
  int _page = 1;
  final int _pageSize = 10;
  int _totalCount = 0;
  String _search = '';
  String? _statusFilter;

  static const _statuses = ['Open', 'PartiallyConsumed', 'Closed'];

  @override
  void initState() {
    super.initState();
    _dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:5000/api',
      headers: {'Authorization': 'Bearer ${widget.token}'},
    ));
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final resp = await _dio.get('/admin/pos', queryParameters: {
        'pageNumber': _page,
        'pageSize': _pageSize,
        if (_search.isNotEmpty) 'search': _search,
        if (_statusFilter != null) 'poStatus': _statusFilter,
      });
      if (resp.statusCode == 200 && mounted) {
        final data = resp.data as Map<String, dynamic>;
        setState(() {
          _pos = List<Map<String, dynamic>>.from(data['items'] as List);
          _totalCount = data['totalCount'] as int;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load POs: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _totalPages => (_totalCount / _pageSize).ceil().clamp(1, 9999);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            const Text('Supplier PO',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF003087))),
            const Spacer(),
            // Status filter
            Container(
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
                  hint: const Text('All Statuses', style: TextStyle(fontSize: 13)),
                  items: [
                    const DropdownMenuItem(value: null,
                        child: Text('All Statuses', style: TextStyle(fontSize: 13))),
                    ..._statuses.map((s) => DropdownMenuItem(
                        value: s, child: Text(s, style: const TextStyle(fontSize: 13)))),
                  ],
                  onChanged: (v) { setState(() { _statusFilter = v; _page = 1; }); _load(); },
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 240,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search PO number or vendor...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                onChanged: (v) { _search = v; _page = 1; _load(); },
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 8),
          // Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _pos.isEmpty
                    ? Center(child: Text('No POs found.',
                        style: TextStyle(color: Colors.grey.shade500)))
                    : _buildTable(),
          ),
          const SizedBox(height: 12),
          // Pagination
          Row(children: [
            Text('Showing $_pageSize of $_totalCount entries',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _page > 1 ? () { setState(() => _page--); _load(); } : null,
            ),
            Text('$_page / $_totalPages', style: const TextStyle(fontSize: 13)),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _page < _totalPages ? () { setState(() => _page++); _load(); } : null,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF0F4FF)),
            headingTextStyle: const TextStyle(
                fontWeight: FontWeight.w600, color: Color(0xFF003087), fontSize: 13),
            dataRowMinHeight: 52,
            dataRowMaxHeight: 52,
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('PO Number')),
              DataColumn(label: Text('Vendor Name')),
              DataColumn(label: Text('Agency')),
              DataColumn(label: Text('Total Amount')),
              DataColumn(label: Text('Remaining Balance')),
              DataColumn(label: Text('PO Date')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Created On')),
            ],
            rows: _pos.map((p) {
              final poDate   = _fmtDate(p['poDate'] as String?);
              final created  = _fmtDate(p['createdAt'] as String?);
              final total    = p['totalAmount'] != null ? '₹${_fmtNum(p['totalAmount'])}' : '—';
              final balance  = p['remainingBalance'] != null ? '₹${_fmtNum(p['remainingBalance'])}' : '—';
              return DataRow(cells: [
                DataCell(Text(p['poNumber'] ?? '—',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                DataCell(Text(p['vendorName'] ?? '—', style: const TextStyle(fontSize: 13))),
                DataCell(Text(
                    '${p['agencyCode'] ?? ''} ${p['agencyName'] ?? ''}'.trim(),
                    style: const TextStyle(fontSize: 13))),
                DataCell(Text(total, style: const TextStyle(fontSize: 13))),
                DataCell(Text(balance, style: const TextStyle(fontSize: 13))),
                DataCell(Text(poDate, style: const TextStyle(fontSize: 13))),
                DataCell(_StatusBadge(status: p['poStatus'] as String?)),
                DataCell(Text(created, style: const TextStyle(fontSize: 13))),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _fmtDate(String? d) {
    if (d == null || d.isEmpty) return '—';
    return d.length >= 10 ? d.substring(0, 10) : d;
  }

  String _fmtNum(dynamic v) {
    if (v == null) return '0';
    final n = (v as num).toDouble();
    return n.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

class _StatusBadge extends StatelessWidget {
  final String? status;
  const _StatusBadge({this.status});

  @override
  Widget build(BuildContext context) {
    final s = status ?? 'Unknown';
    Color bg, fg;
    switch (s) {
      case 'Open':
        bg = const Color(0xFFD1FAE5); fg = const Color(0xFF065F46);
      case 'PartiallyConsumed':
        bg = const Color(0xFFFEF3C7); fg = const Color(0xFF92400E);
      case 'Closed':
        bg = const Color(0xFFFEE2E2); fg = const Color(0xFFDC2626);
      default:
        bg = Colors.grey.shade100; fg = Colors.grey.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(s, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
