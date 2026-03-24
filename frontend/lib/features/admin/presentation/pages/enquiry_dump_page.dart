import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import 'package:dio/dio.dart';
import 'extracted_data_page.dart';

class EnquiryDumpPage extends StatefulWidget {
  final String token;
  const EnquiryDumpPage({super.key, required this.token});

  @override
  State<EnquiryDumpPage> createState() => _EnquiryDumpPageState();
}

class _EnquiryDumpPageState extends State<EnquiryDumpPage> {
  late final Dio _dio;
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _faps      = [];
  List<String>               _locations = [];
  bool    _isLoading     = true;
  int     _page          = 1;
  final   _pageSize      = 10;
  int     _totalCount    = 0;
  int     _totalPages    = 1;
  String? _locationFilter;

  // When non-null, show the detail view inline (keeps drawer/topbar intact)
  Map<String, dynamic>? _selectedFap;

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
      final resp = await _dio.get('/admin/enquiry-dump', queryParameters: {
        'pageNumber': _page,
        'pageSize':   _pageSize,
        if (_searchCtrl.text.trim().isNotEmpty) 'search': _searchCtrl.text.trim(),
        if (_locationFilter != null) 'locationFilter': _locationFilter,
      });
      if (resp.statusCode == 200 && mounted) {
        final data = resp.data as Map<String, dynamic>;
        setState(() {
          _faps       = List<Map<String, dynamic>>.from(data['items'] as List);
          _totalCount = data['totalCount'] as int;
          _totalPages = data['totalPages'] as int? ?? 1;
          _locations  = List<String>.from(data['locations'] as List? ?? []);
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show detail view inline — drawer/topbar from AdminDashboardPage stay intact
    if (_selectedFap != null) {
      return ExtractedDataContent(
        fap: _selectedFap!,
        onBack: () => setState(() => _selectedFap = null),
      );
    }
    return _buildListView();
  }

  Widget _buildListView() {
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
              const Text(
                'Enquiry Data',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003087),
                ),
              ),
              Container(
                width: 180,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _locationFilter,
                    isDense: true,
                    isExpanded: true,
                    hint: const Text('All Locations', style: TextStyle(fontSize: 13)),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Locations', style: TextStyle(fontSize: 13)),
                      ),
                      ..._locations.map(
                        (l) => DropdownMenuItem(
                          value: l,
                          child: Text(l,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() { _locationFilter = v; _page = 1; });
                      _load();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search submission / agency...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  onChanged: (_) { _page = 1; _load(); },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _faps.isEmpty
                    ? Center(
                        child: Text('No enquiry documents found.',
                            style: TextStyle(color: Colors.grey.shade500)),
                      )
                    : _buildTable(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Showing ${_faps.length} of $_totalCount entries',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
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
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF0F4FF)),
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF003087),
                  fontSize: 13,
                ),
                dataRowMinHeight: 52,
                dataRowMaxHeight: 52,
                columnSpacing: 28,
                columns: const [
                  DataColumn(label: Text('Submission No.')),
                  DataColumn(label: Text('Agency Code')),
                  DataColumn(label: Text('Agency Name')),
                  DataColumn(label: Text('Location')),
                  DataColumn(label: Text('File Name')),
                  DataColumn(label: Text('Submitted On')),
                  DataColumn(label: Text('View Data')),
                ],
                rows: _faps.map((fap) {
                  final hasData = fap['extractedDataJson'] != null &&
                      (fap['extractedDataJson'] as String).trim().isNotEmpty;
                  return DataRow(
                    cells: [
                      DataCell(Text(
                        fap['submissionNumber'] ?? '—',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF003087),
                        ),
                      )),
                      DataCell(Text(fap['agencyCode'] ?? '—',
                          style: const TextStyle(fontSize: 13))),
                      DataCell(SizedBox(
                        width: 160,
                        child: Text(fap['agencyName'] ?? '—',
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                      )),
                      DataCell(Text(fap['location'] ?? '—',
                          style: const TextStyle(fontSize: 13))),
                      DataCell(SizedBox(
                        width: 140,
                        child: Text(fap['fileName'] ?? '—',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      )),
                      DataCell(Text(
                        _fmtDate(fap['submittedOn'] as String?),
                        style: const TextStyle(fontSize: 13),
                      )),
                      DataCell(
                        hasData
                            ? TextButton.icon(
                                onPressed: () => setState(() => _selectedFap = fap),
                                icon: const Icon(Icons.table_view_outlined, size: 16),
                                label: const Text('View', style: TextStyle(fontSize: 13)),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF003087),
                                ),
                              )
                            : Text('No data',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _fmtDate(String? d) {
    if (d == null || d.isEmpty) return '—';
    return d.length >= 10 ? d.substring(0, 10) : d;
  }
}
