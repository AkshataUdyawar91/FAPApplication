import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class DealerMasterPage extends StatefulWidget {
  final String token;
  const DealerMasterPage({super.key, required this.token});

  @override
  State<DealerMasterPage> createState() => _DealerMasterPageState();
}

class _DealerMasterPageState extends State<DealerMasterPage> {
  late final Dio _dio;
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  List<String> _states = [];
  bool _isLoading = true;
  int _page = 1;
  final int _pageSize = 10;
  int _totalCount = 0;
  int _totalPages = 1;
  String _search = '';
  String? _stateFilter;

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
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final resp = await _dio.get('/admin/dealers', queryParameters: {
        'pageNumber': _page,
        'pageSize': _pageSize,
        if (_search.isNotEmpty) 'search': _search,
        if (_stateFilter != null) 'stateFilter': _stateFilter,
      });
      if (resp.statusCode == 200 && mounted) {
        final data = resp.data as Map<String, dynamic>;
        setState(() {
          _items      = List<Map<String, dynamic>>.from(data['items'] as List);
          _totalCount = data['totalCount'] as int;
          _totalPages = data['totalPages'] as int? ?? 1;
          _states     = List<String>.from(data['states'] as List? ?? []);
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

  void _openForm({Map<String, dynamic>? item}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DealerFormDialog(token: widget.token, item: item),
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
              const Text('Dealer Master',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                      color: Color(0xFF003087))),
              const SizedBox(width: 16),
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // State filter
                    SizedBox(
                      width: 180,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _stateFilter,
                            isDense: true,
                            isExpanded: true,
                            hint: const Text('All States', style: TextStyle(fontSize: 13)),
                            items: [
                              const DropdownMenuItem(value: null,
                                  child: Text('All States', style: TextStyle(fontSize: 13))),
                              ..._states.map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s, style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis))),
                            ],
                            onChanged: (v) {
                              setState(() { _stateFilter = v; _page = 1; });
                              _load();
                            },
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search code, name, city...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        onChanged: (v) { _search = v; _page = 1; _load(); },
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          const SizedBox(height: 8),
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 8),
          // ── Table ────────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(child: Text('No dealers found.',
                        style: TextStyle(color: Colors.grey.shade500)))
                    : _buildTable(),
          ),
          const SizedBox(height: 12),
          // ── Pagination ───────────────────────────────────────────────────
          Row(children: [
            Text('Showing ${_items.length} of $_totalCount entries',
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
            headingTextStyle: const TextStyle(
                fontWeight: FontWeight.w600, color: Color(0xFF003087), fontSize: 13),
            dataRowMinHeight: 52,
            dataRowMaxHeight: 52,
            columnSpacing: 28,
            columns: const [
              DataColumn(label: Text('Dealer Code')),
              DataColumn(label: Text('Dealer Name')),
              DataColumn(label: Text('State')),
              DataColumn(label: Text('City')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Created On')),
              DataColumn(label: Text('Actions')),
            ],
            rows: _items.map((item) {
              final isActive = item['isActive'] as bool? ?? true;
              final date     = _fmtDate(item['createdAt'] as String?);
              // Support both camelCase (after fix) and PascalCase (before fix)
              final code = (item['dealerCode'] ?? item['DealerCode'] ?? '—') as String;
              final name = (item['dealerName'] ?? item['DealerName'] ?? '—') as String;
              final state = (item['state'] ?? item['State'] ?? '—') as String;
              final city  = (item['city']  ?? item['City']  ?? '—') as String;
              return DataRow(cells: [
                DataCell(Text(code,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: Color(0xFF003087)))),
                DataCell(SizedBox(
                  width: 200,
                  child: Text(name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                )),
                DataCell(Text(state, style: const TextStyle(fontSize: 13))),
                DataCell(Text(city,  style: const TextStyle(fontSize: 13))),
                DataCell(_DealerStatusBadge(isActive: isActive)),
                DataCell(Text(date,  style: const TextStyle(fontSize: 13))),
                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF003087)),
                    tooltip: 'Edit', splashRadius: 18,
                    onPressed: () => _openForm(item: item),
                  ),
                ])),
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
    return d.length >= 10 ? d.substring(0, 10) : d;
  }
}

// ─── Status badge ─────────────────────────────────────────────────────────────
class _DealerStatusBadge extends StatelessWidget {
  final bool isActive;
  const _DealerStatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: isActive ? const Color(0xFFD1FAE5) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      isActive ? 'Active' : 'Inactive',
      style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600,
        color: isActive ? const Color(0xFF065F46) : Colors.grey.shade600,
      ),
    ),
  );
}

// ─── Form Dialog ──────────────────────────────────────────────────────────────
class DealerFormDialog extends StatefulWidget {
  final String token;
  final Map<String, dynamic>? item;
  const DealerFormDialog({super.key, required this.token, this.item});

  @override
  State<DealerFormDialog> createState() => _DealerFormDialogState();
}

class _DealerFormDialogState extends State<DealerFormDialog> {
  final _formKey   = GlobalKey<FormState>();
  final _codeCtrl  = TextEditingController();
  final _nameCtrl  = TextEditingController();
  bool _isSaving   = false;
  bool _isActive   = true;

  List<String> _allStates = [];
  List<String> _cities    = [];
  String? _selectedState;
  String? _selectedCity;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      // Support both camelCase and PascalCase keys
      _codeCtrl.text = (widget.item!['dealerCode'] ?? widget.item!['DealerCode'] ?? '') as String;
      _nameCtrl.text = (widget.item!['dealerName'] ?? widget.item!['DealerName'] ?? '') as String;
      _selectedState = (widget.item!['state']  ?? widget.item!['State'])  as String?;
      _selectedCity  = (widget.item!['city']   ?? widget.item!['City'])   as String?;
      _isActive      = (widget.item!['isActive'] ?? widget.item!['IsActive'] ?? true) as bool;
    }
    _loadStates();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStates() async {
    try {
      final dio = _makeDio();
      final resp = await dio.get('/admin/state-cities',
          queryParameters: {'pageSize': 100});
      if (resp.statusCode == 200 && mounted) {
        final states = List<String>.from(resp.data['states'] as List? ?? []);
        setState(() => _allStates = states);
        if (_selectedState != null) _loadCities(_selectedState!);
      }
    } catch (_) {}
  }

  Future<void> _loadCities(String state) async {
    try {
      final dio = _makeDio();
      final resp = await dio.get('/admin/state-cities', queryParameters: {
        'stateFilter': state,
        'pageSize': 100,
      });
      if (resp.statusCode == 200 && mounted) {
        final raw    = resp.data['items'] as List? ?? [];
        final cities = raw.map((e) => e['city'] as String).toList();
        setState(() {
          _cities = cities;
          if (!cities.contains(_selectedCity)) _selectedCity = null;
        });
      }
    } catch (_) {}
  }

  Dio _makeDio() => Dio(BaseOptions(
    baseUrl: 'http://localhost:5000/api',
    headers: {'Authorization': 'Bearer ${widget.token}'},
  ));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a State'),
            backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final dio = _makeDio();
      if (_isEdit) {
        await dio.put('/admin/dealers/${widget.item!['id']}', data: {
          'dealerName': _nameCtrl.text.trim(),
          'state':      _selectedState,
          'city':       _selectedCity,
          'isActive':   _isActive,
        });
      } else {
        await dio.post('/admin/dealers', data: {
          'dealerCode': _codeCtrl.text.trim(),
          'dealerName': _nameCtrl.text.trim(),
          'state':      _selectedState,
          'city':       _selectedCity,
        });
      }
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Save failed: ${e.response?.data?['message'] ?? e.message}'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(children: [
                  Icon(_isEdit ? Icons.edit_outlined : Icons.store_outlined,
                      color: const Color(0xFF003087)),
                  const SizedBox(width: 10),
                  Text(_isEdit ? 'Edit Dealer' : 'Add Dealer',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                          color: Color(0xFF003087))),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context, false)),
                ]),
                const Divider(height: 20),

                // Scrollable fields
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dealer Code — locked on edit
                        _label('Dealer Code'),
                        TextFormField(
                          controller: _codeCtrl,
                          enabled: !_isEdit,
                          decoration: InputDecoration(
                            hintText: 'e.g. DL001',
                            filled: true,
                            fillColor: _isEdit ? Colors.grey.shade100 : Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade400),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            suffixIcon: _isEdit
                                ? const Icon(Icons.lock_outline, size: 16, color: Colors.grey)
                                : null,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            isDense: true,
                          ),
                          textCapitalization: TextCapitalization.characters,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 14),

                        // Dealer Name
                        _label('Dealer Name'),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: _inputDec('e.g. Bajaj Auto Pune Central'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 14),

                        // State dropdown
                        _label('State'),
                        _dropdown(
                          hint: 'Select State',
                          value: _selectedState,
                          items: _allStates,
                          enabled: true,
                          onChanged: (v) {
                            setState(() {
                              _selectedState = v;
                              _selectedCity  = null;
                              _cities        = [];
                            });
                            if (v != null) _loadCities(v);
                          },
                        ),
                        const SizedBox(height: 14),

                        // City dropdown — disabled until state chosen
                        _label('City'),
                        _dropdown(
                          hint: _selectedState == null
                              ? 'Select State first'
                              : _cities.isEmpty
                                  ? 'Loading...'
                                  : 'Select City',
                          value: _selectedState != null ? _selectedCity : null,
                          items: _selectedState != null ? _cities : [],
                          // onChanged = null disables the DropdownButton natively
                          enabled: _selectedState != null && _cities.isNotEmpty,
                          onChanged: _selectedState != null
                              ? (v) => setState(() => _selectedCity = v)
                              : null,
                        ),
                        const SizedBox(height: 14),

                        // Active toggle — edit only
                        if (_isEdit)
                          Row(children: [
                            const Text('Status',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500)),
                            const Spacer(),
                            Switch(
                              value: _isActive,
                              activeColor: const Color(0xFF003087),
                              onChanged: (v) => setState(() => _isActive = v),
                            ),
                            Text(
                              _isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _isActive
                                    ? const Color(0xFF065F46)
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ]),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003087),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            _isEdit ? 'Save Changes' : 'Add Dealer',
                            style: const TextStyle(
                                fontSize: 15, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Dropdown that is truly disabled when [enabled] is false or [onChanged] is null.
  Widget _dropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
    bool enabled = true,
  }) {
    // The only way to truly disable DropdownButton is onChanged = null
    final effective = (enabled && onChanged != null) ? onChanged : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: effective == null ? Colors.grey.shade100 : Colors.white,
        border: Border.all(
          color: effective == null ? Colors.grey.shade300 : Colors.grey.shade400,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          isDense: true,
          hint: Text(hint,
              style: TextStyle(
                  fontSize: 13,
                  color: effective == null
                      ? Colors.grey.shade400
                      : Colors.grey.shade500)),
          items: items
              .map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s, style: const TextStyle(fontSize: 13))))
              .toList(),
          onChanged: effective,
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
  );

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey.shade400),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    isDense: true,
  );
}
