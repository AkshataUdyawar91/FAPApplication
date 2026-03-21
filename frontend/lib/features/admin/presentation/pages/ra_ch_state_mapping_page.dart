import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class RaChStateMappingPage extends StatefulWidget {
  final String token;
  const RaChStateMappingPage({super.key, required this.token});

  @override
  State<RaChStateMappingPage> createState() => _RaChStateMappingPageState();
}

class _RaChStateMappingPageState extends State<RaChStateMappingPage> {
  late final Dio _dio;
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _items = [];
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
      final resp = await _dio.get('/admin/state-mappings', queryParameters: {
        'pageNumber': _page,
        'pageSize': _pageSize,
        if (_search.isNotEmpty) 'search': _search,
      });
      if (resp.statusCode == 200 && mounted) {
        final data = resp.data as Map<String, dynamic>;
        setState(() {
          _items      = List<Map<String, dynamic>>.from(data['items'] as List);
          _totalCount = data['totalCount'] as int;
          _totalPages = data['totalPages'] as int? ?? 1;
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
      builder: (_) => _StateMappingFormDialog(token: widget.token, item: item),
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
              const Text('State Hierarchy',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF003087))),
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
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search by state...',
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Text('No mappings found.',
                            style:
                                TextStyle(color: Colors.grey.shade500)))
                    : _buildTable(),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Text('Showing ${_items.length} of $_totalCount entries',
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade600)),
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
            dataRowMinHeight: 64,
            dataRowMaxHeight: 72,
            columnSpacing: 32,
            columns: const [
              DataColumn(label: Text('State')),
              DataColumn(label: Text('Circle Head (ASM)')),
              DataColumn(label: Text('RA (Regional Agent)')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Created On')),
              DataColumn(label: Text('Actions')),
            ],
            rows: _items.map((item) {
              final isActive = item['isActive'] as bool? ?? true;
              final date = _fmtDate(item['createdAt'] as String?);
              return DataRow(cells: [
                DataCell(Text(item['state'] ?? '—',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600))),
                DataCell(_UserCell(
                    name: item['chName'] as String?,
                    email: item['chEmail'] as String?,
                    role: 'ASM')),
                DataCell(_UserCell(
                    name: item['raName'] as String?,
                    email: item['raEmail'] as String?,
                    role: 'RA')),
                DataCell(_MappingStatusBadge(isActive: isActive)),
                DataCell(Text(date,
                    style: const TextStyle(fontSize: 13))),
                DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            size: 18, color: Color(0xFF003087)),
                        tooltip: 'Edit',
                        splashRadius: 18,
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

// ─── User cell ────────────────────────────────────────────────────────────────
class _UserCell extends StatelessWidget {
  final String? name;
  final String? email;
  final String role;
  const _UserCell({this.name, this.email, required this.role});

  @override
  Widget build(BuildContext context) {
    if (name == null) {
      return Text('— Not assigned',
          style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
              fontStyle: FontStyle.italic));
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name!,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500)),
        if (email != null)
          Text(email!,
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }
}

// ─── Status badge ─────────────────────────────────────────────────────────────
class _MappingStatusBadge extends StatelessWidget {
  final bool isActive;
  const _MappingStatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFD1FAE5)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          isActive ? 'Active' : 'Inactive',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive
                ? const Color(0xFF065F46)
                : Colors.grey.shade600,
          ),
        ),
      );
}

// ─── Form Dialog ─────────────────────────────────────────────────────────────
class _StateMappingFormDialog extends StatefulWidget {
  final String token;
  final Map<String, dynamic>? item;
  const _StateMappingFormDialog({required this.token, this.item});

  @override
  State<_StateMappingFormDialog> createState() =>
      _StateMappingFormDialogState();
}

class _StateMappingFormDialogState
    extends State<_StateMappingFormDialog> {
  bool _isSaving = false;
  bool _isLoading = true;
  bool _isActive = true;

  List<String> _allStates = [];
  List<_DropItem> _asmItems = [];
  List<_DropItem> _raItems = [];

  String? _selectedState;
  String? _selectedCHId;
  String? _selectedRAId;

  bool get _isEdit => widget.item != null;

  static String? _toId(dynamic v) =>
      v?.toString().toLowerCase();

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _selectedState = widget.item!['state']?.toString();
      _selectedCHId = _toId(widget.item!['circleHeadUserId']);
      _selectedRAId = _toId(widget.item!['rAUserId']);
      _isActive = widget.item!['isActive'] as bool? ?? true;
    }
    _loadDropdownData();
  }

  Future<void> _loadDropdownData() async {
    setState(() => _isLoading = true);
    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'http://localhost:5000/api',
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ));
      final results = await Future.wait([
        dio.get('/admin/state-cities',
            queryParameters: {'pageSize': 100}),
        dio.get('/admin/state-mappings/users'),
      ]);

      if (!mounted) return;

      final statesResp = results[0];
      final usersResp = results[1];

      // Distinct states
      final rawStates = List<String>.from(
          statesResp.data['states'] as List? ?? []);
      final uniqueStates =
          rawStates.toSet().toList()..sort();

      // ASM users — deduplicate by id
      final asmList = List<Map<String, dynamic>>.from(
          usersResp.data['asmUsers'] as List? ?? []);
      final seenAsm = <String>{};
      final asmItems = asmList
          .map((u) => _DropItem(
                id: _toId(u['id']) ?? '',
                label: u['fullName']?.toString() ?? '',
                sub: u['email']?.toString(),
              ))
          .where((i) => i.id.isNotEmpty && seenAsm.add(i.id))
          .toList();

      // RA users — deduplicate by id
      final raList = List<Map<String, dynamic>>.from(
          usersResp.data['raUsers'] as List? ?? []);
      final seenRa = <String>{};
      final raItems = raList
          .map((u) => _DropItem(
                id: _toId(u['id']) ?? '',
                label: u['fullName']?.toString() ?? '',
                sub: u['email']?.toString(),
              ))
          .where((i) => i.id.isNotEmpty && seenRa.add(i.id))
          .toList();

      setState(() {
        _allStates = uniqueStates;
        _asmItems = asmItems;
        _raItems = raItems;

        // Reset selected IDs if not found in loaded lists
        if (_selectedCHId != null &&
            !_asmItems.any((i) => i.id == _selectedCHId)) {
          _selectedCHId = null;
        }
        if (_selectedRAId != null &&
            !_raItems.any((i) => i.id == _selectedRAId)) {
          _selectedRAId = null;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to load data: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (_selectedState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a State'),
            backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _isSaving = true);
    final dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:5000/api',
      headers: {'Authorization': 'Bearer ${widget.token}'},
    ));
    try {
      if (_isEdit) {
        await dio.put(
            '/admin/state-mappings/${widget.item!['id']}',
            data: {
              'circleHeadUserId': _selectedCHId,
              'rAUserId': _selectedRAId,
              'isActive': _isActive,
            });
      } else {
        await dio.post('/admin/state-mappings', data: {
          'state': _selectedState,
          'circleHeadUserId': _selectedCHId,
          'rAUserId': _selectedRAId,
        });
      }
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Save failed: ${e.response?.data?['message'] ?? e.message}'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: 500, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _isLoading
              ? const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()))
              : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row
        Row(children: [
          Icon(
              _isEdit
                  ? Icons.edit_outlined
                  : Icons.account_tree_outlined,
              color: const Color(0xFF003087)),
          const SizedBox(width: 10),
          Text(
            _isEdit ? 'Edit Mapping' : 'Add State Mapping',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF003087)),
          ),
          const Spacer(),
          IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context, false)),
        ]),
        const Divider(height: 20),

        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── State picker ──────────────────────────────
                _label('State'),
                _isEdit
                    ? _lockedField(_selectedState ?? '—')
                    : _ExpansionPicker(
                        hint: 'Select State',
                        selected: _selectedState,
                        items: _allStates
                            .map((s) =>
                                _DropItem(id: s, label: s))
                            .toList(),
                        onSelect: (v) =>
                            setState(() => _selectedState = v),
                      ),
                const SizedBox(height: 16),

                // ── Circle Head (ASM) picker ──────────────────
                _label('Circle Head (ASM)'),
                _ExpansionPicker(
                  hint: 'Select ASM User',
                  selected: _selectedCHId,
                  items: _asmItems,
                  onSelect: (v) =>
                      setState(() => _selectedCHId = v),
                ),
                const SizedBox(height: 16),

                // ── RA picker ─────────────────────────────────
                _label('Regional Agent (RA)'),
                _ExpansionPicker(
                  hint: 'Select RA User',
                  selected: _selectedRAId,
                  items: _raItems,
                  onSelect: (v) =>
                      setState(() => _selectedRAId = v),
                ),
                const SizedBox(height: 16),

                // ── Active toggle (edit only) ─────────────────
                if (_isEdit) ...[
                  Row(children: [
                    const Text('Status',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Switch(
                      value: _isActive,
                      activeColor: const Color(0xFF003087),
                      onChanged: (v) =>
                          setState(() => _isActive = v),
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
                  const SizedBox(height: 8),
                ],
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
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(
                    _isEdit ? 'Save Changes' : 'Add Mapping',
                    style: const TextStyle(
                        fontSize: 15, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  /// Read-only locked field shown in edit mode for State.
  Widget _lockedField(String value) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade700)),
        ),
        const Icon(Icons.lock_outline,
            size: 15, color: Colors.grey),
      ]),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500)),
      );
}

// ─── Expansion-based picker (replaces DropdownButton) ────────────────────────
class _ExpansionPicker extends StatefulWidget {
  final String hint;
  final String? selected;
  final List<_DropItem> items;
  final ValueChanged<String?> onSelect;

  const _ExpansionPicker({
    required this.hint,
    required this.selected,
    required this.items,
    required this.onSelect,
  });

  @override
  State<_ExpansionPicker> createState() => _ExpansionPickerState();
}

class _ExpansionPickerState extends State<_ExpansionPicker> {
  bool _expanded = false;

  String get _displayLabel {
    if (widget.selected == null) return widget.hint;
    final match = widget.items
        .where((i) => i.id == widget.selected)
        .firstOrNull;
    return match?.label ?? widget.hint;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header — tap to expand/collapse
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                  color: _expanded
                      ? const Color(0xFF003087)
                      : Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  _displayLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.selected == null
                        ? Colors.grey.shade500
                        : Colors.black87,
                  ),
                ),
              ),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 20,
                color: Colors.grey.shade600,
              ),
            ]),
          ),
        ),

        // Expanded list
        if (_expanded)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFF003087)),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: widget.items.length,
              itemBuilder: (_, i) {
                final item = widget.items[i];
                final isSelected = item.id == widget.selected;
                return InkWell(
                  onTap: () {
                    widget.onSelect(item.id);
                    setState(() => _expanded = false);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    color: isSelected
                        ? const Color(0xFFEEF2FF)
                        : Colors.transparent,
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(item.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? const Color(0xFF003087)
                                      : Colors.black87,
                                )),
                            if (item.sub != null)
                              Text(item.sub!,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          Colors.grey.shade500)),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check,
                            size: 16,
                            color: Color(0xFF003087)),
                    ]),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _DropItem {
  final String id;
  final String label;
  final String? sub;
  const _DropItem({required this.id, required this.label, this.sub});
}
