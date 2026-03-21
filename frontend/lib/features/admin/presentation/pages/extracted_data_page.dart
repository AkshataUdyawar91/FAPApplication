import 'dart:convert';
import 'package:flutter/material.dart';

/// Inline content widget — rendered inside AdminDashboardPage's shell
/// so the drawer and topbar remain visible.
class ExtractedDataContent extends StatefulWidget {
  final Map<String, dynamic> fap;
  final VoidCallback onBack;

  const ExtractedDataContent({
    super.key,
    required this.fap,
    required this.onBack,
  });

  @override
  State<ExtractedDataContent> createState() => _ExtractedDataContentState();
}

class _ExtractedDataContentState extends State<ExtractedDataContent> {
  final _locationCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _dealerCtrl   = TextEditingController();
  final _teamCtrl     = TextEditingController();
  final _customerCtrl = TextEditingController();

  late List<Map<String, dynamic>> _allRows;
  late List<Map<String, dynamic>> _filtered;

  @override
  void initState() {
    super.initState();
    _allRows  = _parse();
    _filtered = List.from(_allRows);
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _districtCtrl.dispose();
    _dealerCtrl.dispose();
    _teamCtrl.dispose();
    _customerCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _parse() {
    final raw = widget.fap['extractedDataJson'] as String? ?? '';
    if (raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
            .toList();
      }
      if (decoded is Map) {
        final m = Map<String, dynamic>.from(decoded);
        if (m['entries'] is List) {
          return (m['entries'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
        if (m['data'] is List) {
          return (m['data'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
        return [m];
      }
    } catch (_) {}
    return [];
  }

  void _applyFilters() {
    final loc  = _locationCtrl.text.trim().toLowerCase();
    final dist = _districtCtrl.text.trim().toLowerCase();
    final deal = _dealerCtrl.text.trim().toLowerCase();
    final team = _teamCtrl.text.trim().toLowerCase();
    final cust = _customerCtrl.text.trim().toLowerCase();

    setState(() {
      _filtered = _allRows.where((row) {
        if (loc.isNotEmpty  && !_match(row, loc,  ['location', 'state', 'city'])) return false;
        if (dist.isNotEmpty && !_match(row, dist, ['district', 'taluka', 'area'])) return false;
        if (deal.isNotEmpty && !_match(row, deal, ['dealer', 'dealerName', 'dealership'])) return false;
        if (team.isNotEmpty && !_match(row, team, ['team', 'teamName'])) return false;
        if (cust.isNotEmpty && !_match(row, cust, ['customer', 'customerName', 'name', 'mobile'])) return false;
        return true;
      }).toList();
    });
  }

  bool _match(Map<String, dynamic> row, String q, List<String> keys) {
    for (final k in keys) {
      for (final rk in row.keys) {
        if (rk.toLowerCase() == k.toLowerCase() &&
            row[rk]?.toString().toLowerCase().contains(q) == true) {
          return true;
        }
      }
    }
    return row.values.any((v) => v?.toString().toLowerCase().contains(q) == true);
  }

  void _clearFilters() {
    _locationCtrl.clear();
    _districtCtrl.clear();
    _dealerCtrl.clear();
    _teamCtrl.clear();
    _customerCtrl.clear();
    setState(() => _filtered = List.from(_allRows));
  }

  List<String> get _columns {
    final keys = <String>{};
    for (final row in _allRows) {
      keys.addAll(row.keys);
    }
    return keys.toList();
  }

  String _fmt(String key) {
    var s = key.replaceAll('_', ' ');
    s = s.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    return s.isEmpty ? key : s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final cols = _columns;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Breadcrumb / back header ──────────────────────────────────
          Row(
            children: [
              InkWell(
                onTap: widget.onBack,
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_ios_new,
                        size: 14, color: Color(0xFF003087)),
                    const SizedBox(width: 4),
                    Text(
                      'Enquiry Data',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${widget.fap['submissionNumber'] ?? ''}'
                  '${widget.fap['agencyName'] != null ? ' — ${widget.fap['agencyName']}' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF003087),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Extracted Data',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF003087),
            ),
          ),
          const SizedBox(height: 4),
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 12),

          // ── Filters ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDDE3F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.filter_list, size: 16, color: Color(0xFF003087)),
                    const SizedBox(width: 6),
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF003087),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.clear_all, size: 15),
                      label: const Text('Clear All', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _fBox(_locationCtrl, 'Location', Icons.location_on_outlined)),
                    const SizedBox(width: 12),
                    Expanded(child: _fBox(_districtCtrl, 'District', Icons.map_outlined)),
                    const SizedBox(width: 12),
                    Expanded(child: _fBox(_dealerCtrl, 'Dealer', Icons.store_outlined)),
                    const SizedBox(width: 12),
                    Expanded(child: _fBox(_teamCtrl, 'Team', Icons.group_outlined)),
                    const SizedBox(width: 12),
                    Expanded(child: _fBox(_customerCtrl, 'Customer', Icons.person_outline)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Record count ──────────────────────────────────────────────
          Text(
            'Showing ${_filtered.length} of ${_allRows.length} records',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),

          // ── Data table ────────────────────────────────────────────────
          Expanded(
            child: _allRows.isEmpty
                ? Center(
                    child: Text(
                      'No extracted data available.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No records match the filters.',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: LayoutBuilder(
                            builder: (context, constraints) => SingleChildScrollView(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(
                                        const Color(0xFFF0F4FF)),
                                    headingTextStyle: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF003087),
                                      fontSize: 13,
                                    ),
                                    dataRowMinHeight: 48,
                                    dataRowMaxHeight: 48,
                                    columnSpacing: 24,
                                    columns: cols
                                        .map((c) => DataColumn(label: Text(_fmt(c))))
                                        .toList(),
                                    rows: _filtered.map((row) {
                                      return DataRow(
                                        cells: cols.map((c) {
                                          return DataCell(
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 180),
                                              child: Text(
                                                row[c]?.toString() ?? '—',
                                                style: const TextStyle(fontSize: 13),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _fBox(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12),
        prefixIcon: Icon(icon, size: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 13),
      onChanged: (_) => _applyFilters(),
    );
  }
}
