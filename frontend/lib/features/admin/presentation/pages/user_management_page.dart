import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../widgets/user_form_dialog.dart';
import '../widgets/user_table.dart';
import '../../data/models/user_dto.dart';

class UserManagementPage extends StatefulWidget {
  final String token;
  const UserManagementPage({super.key, required this.token});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  late final Dio _dio;
  final _searchController = TextEditingController();

  List<UserDto> _users = [];
  bool _isLoading = true;
  int _page = 1;
  int _pageSize = 10;
  int _totalCount = 0;
  String _search = '';
  int? _roleFilter;

  @override
  void initState() {
    super.initState();
    _dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:5000/api',
      headers: {'Authorization': 'Bearer ${widget.token}'},
    ));
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final resp = await _dio.get('/admin/users', queryParameters: {
        'pageNumber': _page,
        'pageSize': _pageSize,
        if (_search.isNotEmpty) 'search': _search,
        if (_roleFilter != null) 'role': _roleFilter,
      });
      if (resp.statusCode == 200 && mounted) {
        final data = resp.data as Map<String, dynamic>;
        setState(() {
          _users = (data['items'] as List)
              .map((e) => UserDto.fromJson(e as Map<String, dynamic>))
              .toList();
          _totalCount = data['totalCount'] as int;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUser(UserDto user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.fullName}?'),
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
      await _dio.delete('/admin/users/${user.id}');
      _loadUsers();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _openForm({UserDto? user}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UserFormDialog(token: widget.token, user: user),
    );
    if (saved == true) _loadUsers();
  }

  int get _totalPages => (_totalCount / _pageSize).ceil().clamp(1, 9999);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Text('User Management',
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
              // Role filter
              Container(
                width: 160,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _roleFilter,
                    hint: const Text('All Roles', style: TextStyle(fontSize: 13)),
                    isDense: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Roles', style: TextStyle(fontSize: 13))),
                      const DropdownMenuItem(value: 1, child: Text('Agency', style: TextStyle(fontSize: 13))),
                      const DropdownMenuItem(value: 2, child: Text('ASM', style: TextStyle(fontSize: 13))),
                      const DropdownMenuItem(value: 3, child: Text('RA', style: TextStyle(fontSize: 13))),
                      const DropdownMenuItem(value: 4, child: Text('Admin', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (v) {
                      setState(() { _roleFilter = v; _page = 1; });
                      _loadUsers();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search name or email...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    _search = v;
                    _page = 1;
                    _loadUsers();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 8),
          // Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? Center(child: Text('No users found.', style: TextStyle(color: Colors.grey.shade500)))
                    : UserTable(
                        users: _users,
                        onEdit: (u) => _openForm(user: u),
                        onDelete: _deleteUser,
                      ),
          ),
          const SizedBox(height: 12),
          // Pagination
          Row(
            children: [
              Text('Showing $_pageSize of $_totalCount entries',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _page > 1 ? () { setState(() => _page--); _loadUsers(); } : null,
              ),
              Text('$_page / $_totalPages', style: const TextStyle(fontSize: 13)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _page < _totalPages ? () { setState(() => _page++); _loadUsers(); } : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
