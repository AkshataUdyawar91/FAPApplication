import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/failures.dart';
import 'package:dio/dio.dart';
import '../../data/models/user_dto.dart';

class UserFormDialog extends StatefulWidget {
  final String token;
  final UserDto? user; // null = create, non-null = edit

  const UserFormDialog({super.key, required this.token, this.user});

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl     = TextEditingController();
  final _phoneCtrl    = TextEditingController();

  int _role = 1;
  bool _isActive = true;
  bool _isSaving = false;
  bool _obscure = true;

  bool get _isEdit => widget.user != null;

  static const _roles = [
    (label: 'Agency', value: 1),
    (label: 'ASM',    value: 2),
    (label: 'RA',     value: 3),
    (label: 'Admin',  value: 4),
  ];

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final u = widget.user!;
      _emailCtrl.text = u.email;
      _nameCtrl.text  = u.fullName;
      _phoneCtrl.text = u.phoneNumber ?? '';
      _role           = u.roleValue;
      _isActive       = u.isActive;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
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
      if (_isEdit) {
        final body = {
          'fullName':    _nameCtrl.text.trim(),
          'role':        _role,
          'phoneNumber': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          'isActive':    _isActive,
          if (_passwordCtrl.text.isNotEmpty) 'password': _passwordCtrl.text,
        };
        await dio.put('/admin/users/${widget.user!.id}', data: body);
      } else {
        final body = {
          'email':       _emailCtrl.text.trim(),
          'password':    _passwordCtrl.text,
          'fullName':    _nameCtrl.text.trim(),
          'role':        _role,
          'phoneNumber': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          'isActive':    _isActive,
        };
        await dio.post('/admin/users', data: body);
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(children: [
                  Icon(_isEdit ? Icons.edit_outlined : Icons.person_add_outlined,
                      color: const Color(0xFF003087)),
                  const SizedBox(width: 10),
                  Text(_isEdit ? 'Edit User' : 'Create New User',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                          color: Color(0xFF003087))),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context, false)),
                ]),
                const Divider(height: 24),

                // Email (create only)
                if (!_isEdit) ...[
                  _label('Email'),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDec('Enter email'),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null,
                  ),
                  const SizedBox(height: 14),
                ],

                // Full Name
                _label('Full Name'),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _inputDec('Enter full name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),

                // Password
                _label(_isEdit ? 'New Password (leave blank to keep)' : 'Password'),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: _inputDec('Enter password').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (!_isEdit && (v == null || v.length < 8)) return 'Min 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Role + Phone row
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _label('Role'),
                    DropdownButtonFormField<int>(
                      value: _role,
                      decoration: _inputDec(''),
                      items: _roles.map((r) => DropdownMenuItem(
                        value: r.value,
                        child: Text(r.label),
                      )).toList(),
                      onChanged: (v) => setState(() => _role = v!),
                    ),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _label('Phone Number'),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDec('+91-XXXXXXXXXX'),
                    ),
                  ])),
                ]),
                const SizedBox(height: 14),

                // Is Active toggle
                Row(children: [
                  const Text('Active', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Switch(
                    value: _isActive,
                    activeColor: const Color(0xFF003087),
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ]),
                const SizedBox(height: 20),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003087),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSaving
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_isEdit ? 'Save Changes' : 'Create User',
                            style: const TextStyle(fontSize: 15, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
  );

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    isDense: true,
  );
}
