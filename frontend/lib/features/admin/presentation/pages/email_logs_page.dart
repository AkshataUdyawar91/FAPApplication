import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/failures.dart';
import 'package:dio/dio.dart';

class EmailLogsPage extends StatefulWidget {
  final String token;
  const EmailLogsPage({super.key, required this.token});

  @override
  State<EmailLogsPage> createState() => _EmailLogsPageState();
}

class _EmailLogsPageState extends State<EmailLogsPage> {
  late final Dio _dio;
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  int _page = 1;
  final int _pageSize = 10;
  int _totalCount = 0;
  int _totalPages = 1;
  String _search = '';
  bool? _successFilter;

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
      final resp = await _dio.get('/admin/email-logs', queryParameters: {
        'pageNumber': _page,
        'pageSize': _pageSize,
        if (_search.isNotEmpty) 'search': _search,
        if (_successFilter != null) 'success': _successFilter,
      });
      if (resp.statusCode == 200 && mounted) {
        final data = resp.data as Map<String, dynamic>;
        setState(() {
          _logs       = List<Map<String, dynamic>>.from(data['items'] as List);
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
              const Text('Email Logs',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF003087))),
              Container(
                width: 160,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<bool?>(
                    value: _successFilter,
                    isDense: true,
                    isExpanded: true,
                    hint: const Text('All Status', style: TextStyle(fontSize: 13)),
                    items: const [
                      DropdownMenuItem(value: null,  child: Text('All Status',  style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: true,  child: Text('Success',     style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: false, child: Text('Failed',      style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (v) { setState(() { _successFilter = v; _page = 1; }); _load(); },
                  ),
                ),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search email or subject...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  onChanged: (v) { _search = v; _page = 1; _load(); },
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
                : _logs.isEmpty
                    ? Center(child: Text('No email logs found.', style: TextStyle(color: Colors.grey.shade500)))
                    : _buildTable(),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Text('Showing ${_logs.length} of $_totalCount entries',
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
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
            headingTextStyle: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF003087), fontSize: 13),
            dataRowMinHeight: 52,
            dataRowMaxHeight: 52,
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('Recipient')),
              DataColumn(label: Text('Subject')),
              DataColumn(label: Text('Template')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Attempts')),
              DataColumn(label: Text('Error')),
              DataColumn(label: Text('Sent On')),
            ],
            rows: _logs.map((log) {
              final sentAt   = _fmtDate(log['sentAt'] as String?);
              final success  = log['success'] as bool? ?? false;
              final attempts = log['attemptsCount'] ?? 1;
              final error    = log['errorMessage'] as String?;
              return DataRow(cells: [
                DataCell(Text(log['recipientEmail'] ?? '—', style: const TextStyle(fontSize: 13))),
                DataCell(SizedBox(width: 220,
                    child: Text(log['subject'] ?? '—', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))),
                DataCell(_TemplateBadge(template: log['templateName'] as String?)),
                DataCell(_StatusBadge(success: success)),
                DataCell(Text('$attempts', style: const TextStyle(fontSize: 13))),
                DataCell(SizedBox(width: 180,
                    child: Text(error ?? '—',
                        style: TextStyle(fontSize: 12, color: error != null ? Colors.red.shade700 : Colors.grey),
                        overflow: TextOverflow.ellipsis))),
                DataCell(Text(sentAt, style: const TextStyle(fontSize: 13))),
              ]);
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
    return d.length >= 16 ? d.substring(0, 16).replaceAll('T', ' ') : d;
  }
}

class _StatusBadge extends StatelessWidget {
  final bool success;
  const _StatusBadge({required this.success});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: success ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(success ? 'Success' : 'Failed',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: success ? const Color(0xFF065F46) : const Color(0xFFDC2626))),
  );
}

class _TemplateBadge extends StatelessWidget {
  final String? template;
  const _TemplateBadge({this.template});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
    child: Text(template ?? 'unknown',
        style: const TextStyle(fontSize: 11, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w500)),
  );
}
