import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/failures.dart';
import 'package:dio/dio.dart';

class StateCityMasterPage extends StatefulWidget {
  final String token;
  const StateCityMasterPage({super.key, required this.token});

  @override
  State<StateCityMasterPage> createState() => _StateCityMasterPageState();
}

class _StateCityMasterPageState extends State<StateCityMasterPage> {
  late final Dio _dio;
  final _searchController = TextEditingController();

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
      final resp = await _dio.get('/admin/state-cities', queryParameters: {
        'pageNumber': _page,
        'pageSize': _pageSize,
        if (_search.isNotEmpty) 'search': _search,
        if (_stateFilter != null) 'stateFilter': _stateFilter,
      });
      if (resp.statusCode == 200 && mounted) {
        final data = resp.data as Map<String, dynamic>;
        setState(() {
          _items = List<Map<String, dynamic>>.from(data['items'] as List);
          _totalCount = data['totalCount'] as int;
          _totalPages = data['totalPages'] as int? ?? 1;
          _states = List<String>.from(data['states'] as List? ?? []);
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

  void _openForm({Map<String, dynamic>? item}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StateCityFormDialog(token: widget.token, item: item),
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
                'State City Master',
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
                            hint: const Text('All States',
                                style: TextStyle(fontSize: 13)),
                            items: [
                              const DropdownMenuItem(
                                  value: null,
                                  child: Text('All States',
                                      style: TextStyle(fontSize: 13))),
                              ..._states.map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s,
                                      style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis))),
                            ],
                            onChanged: (v) {
                              setState(() {
                                _stateFilter = v;
                                _page = 1;
                              });
                              _load();
                            },
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search state or city...',
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
                        child: Text('No records found.',
                            style:
                                TextStyle(color: Colors.grey.shade500)))
                    : _buildTable(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Showing ${_items.length} of $_totalCount entries',
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
            columnSpacing: 40,
            columns: const [
              DataColumn(label: Text('State')),
              DataColumn(label: Text('City')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Created On')),
              DataColumn(label: Text('Actions')),
            ],
            rows: _items.map((item) {
              final date = _fmtDate(item['createdAt'] as String?);
              final isActive = item['isActive'] as bool? ?? true;
              return DataRow(cells: [
                DataCell(Text(item['state'] ?? '—',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500))),
                DataCell(Text(item['city'] ?? '—',
                    style: const TextStyle(fontSize: 13))),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
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
                )),
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
                      onPressed: () => _openForm(item: item),
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

  String _fmtDate(String? d) {
    if (d == null || d.isEmpty) return '—';
    return d.length >= 10 ? d.substring(0, 10) : d;
  }
}

// ─── Form Dialog ──────────────────────────────────────────────────────────────
class _StateCityFormDialog extends StatefulWidget {
  final String token;
  final Map<String, dynamic>? item;
  const _StateCityFormDialog({required this.token, this.item});

  @override
  State<_StateCityFormDialog> createState() => _StateCityFormDialogState();
}

class _StateCityFormDialogState extends State<_StateCityFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _stateCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  bool _isSaving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _stateCtrl.text = widget.item!['state'] ?? '';
      _cityCtrl.text = widget.item!['city'] ?? '';
    }
  }

  @override
  void dispose() {
    _stateCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Failure _mapExceptionToFailure(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return const NetworkFailure('Connection timeout');
        case DioExceptionType.badResponse:
          final statusCode = e.response?.statusCode;
          if (statusCode == 401) return const AuthFailure('Unauthorized');
          if (statusCode == 403) return const AuthFailure('Forbidden');
          if (statusCode == 404) return const NotFoundFailure();
          return ServerFailure(e.response?.data?['message']?.toString() ?? 'Server error');
        default:
          return const NetworkFailure();
      }
    }
    return ServerFailure(e.toString());
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      headers: {'Authorization': 'Bearer ${widget.token}'},
    ));
    try {
      final body = {
        'state': _stateCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
      };
      if (_isEdit) {
        await dio.put('/admin/state-cities/${widget.item!['id']}',
            data: body);
      } else {
        await dio.post('/admin/state-cities', data: body);
      }
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (e) {
      if (mounted) {
        ErrorHandler.show(context, failure: _mapExceptionToFailure(e));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(
                      _isEdit
                          ? Icons.edit_outlined
                          : Icons.add_location_outlined,
                      color: const Color(0xFF003087)),
                  const SizedBox(width: 10),
                  Text(
                    _isEdit ? 'Edit State/City' : 'Add State/City',
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
                const Divider(height: 24),
                _label('State'),
                TextFormField(
                  controller: _stateCtrl,
                  enabled: !_isEdit,
                  decoration: _dec('e.g. Maharashtra').copyWith(
                    filled: true,
                    fillColor:
                        _isEdit ? Colors.grey.shade100 : Colors.white,
                    suffixIcon: _isEdit
                        ? const Icon(Icons.lock_outline,
                            size: 16, color: Colors.grey)
                        : null,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _label('City'),
                TextFormField(
                  controller: _cityCtrl,
                  decoration: _dec('e.g. Pune'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 24),
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
                            _isEdit ? 'Save Changes' : 'Add Record',
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

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500)),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      );
}
