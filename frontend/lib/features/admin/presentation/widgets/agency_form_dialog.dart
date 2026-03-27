import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/failures.dart';
import 'package:dio/dio.dart';
import '../../data/models/agency_dto.dart';

class AgencyFormDialog extends StatefulWidget {
  final String token;
  final AgencyDto? agency;
  const AgencyFormDialog({super.key, required this.token, this.agency});

  @override
  State<AgencyFormDialog> createState() => _AgencyFormDialogState();
}

class _AgencyFormDialogState extends State<AgencyFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isSaving = false;

  bool get _isEdit => widget.agency != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _codeCtrl.text = widget.agency!.supplierCode;
      _nameCtrl.text = widget.agency!.supplierName;
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
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
        'supplierCode': _codeCtrl.text.trim(),
        'supplierName': _nameCtrl.text.trim(),
      };
      if (_isEdit) {
        await dio.put('/admin/agencies/${widget.agency!.id}', data: body);
      } else {
        await dio.post('/admin/agencies', data: body);
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
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(_isEdit ? Icons.edit_outlined : Icons.business_outlined,
                      color: const Color(0xFF003087)),
                  const SizedBox(width: 10),
                  Text(_isEdit ? 'Edit Agency' : 'Create New Agency',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                          color: Color(0xFF003087))),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context, false)),
                ]),
                const Divider(height: 24),
                _label('Supplier Code'),
                TextFormField(
                  controller: _codeCtrl,
                  readOnly: _isEdit,
                  style: TextStyle(color: _isEdit ? Colors.grey.shade600 : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'e.g. V001',
                    filled: true,
                    fillColor: _isEdit ? Colors.grey.shade100 : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    isDense: true,
                    suffixIcon: _isEdit
                        ? const Tooltip(
                            message: 'Supplier code cannot be changed',
                            child: Icon(Icons.lock_outline, size: 16, color: Colors.grey))
                        : null,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _label('Supplier Name'),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Demo Agency Pvt Ltd',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 24),
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
                        : Text(_isEdit ? 'Save Changes' : 'Create Agency',
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

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
  );
}
