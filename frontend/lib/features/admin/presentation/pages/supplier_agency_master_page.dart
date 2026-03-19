import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../data/models/agency_dto.dart';
import '../widgets/agency_form_dialog.dart';

class SupplierAgencyMasterPage extends StatefulWidget {
  final String token;
  const SupplierAgencyMasterPage({super.key, required this.token});

  @override
  State<SupplierAgencyMasterPage> createState() => _SupplierAgencyMasterPageState();
}

class _SupplierAgencyMasterPageState extends State<SupplierAgencyMasterPage> {
  late final Dio _dio;
  final _searchController = TextEditingController();

  List<AgencyDto> _agencies = [];
  bool _isLoading = true;
  int _page = 1;
  final int _pageSize = 10;
  int _totalCount = 0;
  String _search = '';

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
      final resp = await _dio.get('/admin/agencies', queryParameters: {
        'pageNumber': _page,
        'pageSize': _pageSize,
        if (_search.isNotEmpty) 'search': _search,
      });
      if (resp.statusCode == 200 && mounted) {
        final data = resp.data as Map<String, dynamic>;
        setState(() {
          _agencies = (data['items'] as List)
              .map((e) => AgencyDto.fromJson(e as Map<String, dynamic>))
              .toList();
          _totalCount = data['totalCount'] as int;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load agencies: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete(AgencyDto agency) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Agency'),
        content: Text('Delete "${agency.supplierName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _dio.delete('/admin/agencies/${agency.id}');
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _openForm({AgencyDto? agency}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AgencyFormDialog(token: widget.token, agency: agency),
    );
    if (saved == true) _load();
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
            const Text('Supplier / Agency Master',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF003087))),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('CREATE NEW'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003087),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 240,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search code or name...',
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
                : _agencies.isEmpty
                    ? Center(child: Text('No agencies found.', style: TextStyle(color: Colors.grey.shade500)))
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
            columnSpacing: 32,
            columns: const [
              DataColumn(label: Text('Supplier Code')),
              DataColumn(label: Text('Supplier Name')),
              DataColumn(label: Text('Created On')),
              DataColumn(label: Text('Actions')),
            ],
            rows: _agencies.map((a) {
              final date = a.createdAt.length >= 10 ? a.createdAt.substring(0, 10) : a.createdAt;
              return DataRow(cells: [
                DataCell(Text(a.supplierCode, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                DataCell(Text(a.supplierName, style: const TextStyle(fontSize: 13))),
                DataCell(Text(date, style: const TextStyle(fontSize: 13))),
                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF003087)),
                    tooltip: 'Edit', splashRadius: 18,
                    onPressed: () => _openForm(agency: a),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    tooltip: 'Delete', splashRadius: 18,
                    onPressed: () => _delete(a),
                  ),
                ])),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
