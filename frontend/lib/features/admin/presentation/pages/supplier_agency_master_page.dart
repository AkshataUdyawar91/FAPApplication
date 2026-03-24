import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import 'package:dio/dio.dart';
import '../../data/models/agency_dto.dart';
import '../widgets/agency_form_dialog.dart';

class SupplierAgencyMasterPage extends StatefulWidget {
  final String token;
  const SupplierAgencyMasterPage({super.key, required this.token});

  @override
  State<SupplierAgencyMasterPage> createState() =>
      _SupplierAgencyMasterPageState();
}

class _SupplierAgencyMasterPageState
    extends State<SupplierAgencyMasterPage> {
  late final Dio _dio;
  final _searchController = TextEditingController();

  List<AgencyDto> _agencies = [];
  bool _isLoading = true;
  int _page = 1;
  final int _pageSize = 10;
  int _totalCount = 0;
  int _totalPages = 1;
  String _search = '';

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
          _totalPages = data['totalPages'] as int? ?? 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load agencies: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Agency Master',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003087)),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 240,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search code or name...',
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
                    Builder(
                      builder: (context) {
                        final w = MediaQuery.of(context).size.width;
                        final fontSize = w < 600 ? 11.0 : w < 900 ? 12.0 : 13.0;
                        final iconSize = w < 600 ? 14.0 : 16.0;
                        final hPad = w < 600 ? 12.0 : 20.0;
                        final vPad = w < 600 ? 8.0 : 12.0;
                        return ElevatedButton.icon(
                          onPressed: () => _openForm(),
                          icon: Icon(Icons.add, size: iconSize),
                          label: Text('CREATE NEW',
                              style: TextStyle(fontSize: fontSize)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF003087),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            padding: EdgeInsets.symmetric(
                                horizontal: hPad, vertical: vPad),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 8),
          // ── Table ────────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _agencies.isEmpty
                    ? Center(
                        child: Text('No agencies found.',
                            style:
                                TextStyle(color: Colors.grey.shade500)))
                    : _buildTable(),
          ),
          const SizedBox(height: 12),
          // ── Pagination ───────────────────────────────────────────────────
          Row(
            children: [
              Text(
                'Showing ${_agencies.length} of $_totalCount entries',
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8),
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
            columnSpacing: 32,
            columns: const [
              DataColumn(label: Text('Supplier Code')),
              DataColumn(label: Text('Supplier Name')),
              DataColumn(label: Text('Created On')),
              DataColumn(label: Text('Actions')),
            ],
            rows: _agencies.map((a) {
              final date = a.createdAt.length >= 10
                  ? a.createdAt.substring(0, 10)
                  : a.createdAt;
              return DataRow(cells: [
                DataCell(Text(a.supplierCode,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500))),
                DataCell(Text(a.supplierName,
                    style: const TextStyle(fontSize: 13))),
                DataCell(
                    Text(date, style: const TextStyle(fontSize: 13))),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 18, color: Color(0xFF003087)),
                      tooltip: 'Edit',
                      splashRadius: 18,
                      onPressed: () => _openForm(agency: a),
                    ),
                  ],
                )),
              ]);
            }).toList(),
          ),
            ),
          ),
        ),
      ),
    );
  }
}
