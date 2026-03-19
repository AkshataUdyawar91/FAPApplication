import 'package:flutter/material.dart';
import '../../data/models/user_dto.dart';

class UserTable extends StatelessWidget {
  final List<UserDto> users;
  final void Function(UserDto) onEdit;
  final void Function(UserDto) onDelete;

  const UserTable({
    super.key,
    required this.users,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF0F4FF)),
            headingTextStyle: const TextStyle(
                fontWeight: FontWeight.w600, color: Color(0xFF003087), fontSize: 13),
            dataRowMinHeight: 52,
            dataRowMaxHeight: 52,
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('Full Name')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Role')),
              DataColumn(label: Text('Phone')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Created On')),
              DataColumn(label: Text('Actions')),
            ],
            rows: users.map((u) => _buildRow(u)).toList(),
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(UserDto u) {
    final date = u.createdAt.length >= 10 ? u.createdAt.substring(0, 10) : u.createdAt;
    return DataRow(cells: [
      DataCell(Text(u.fullName, style: const TextStyle(fontSize: 13))),
      DataCell(Text(u.email, style: const TextStyle(fontSize: 13))),
      DataCell(_RoleBadge(role: u.role)),
      DataCell(Text(u.phoneNumber ?? '—', style: const TextStyle(fontSize: 13))),
      DataCell(_StatusBadge(isActive: u.isActive)),
      DataCell(Text(date, style: const TextStyle(fontSize: 13))),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF003087)),
            tooltip: 'Edit',
            splashRadius: 18,
            onPressed: () => onEdit(u),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            tooltip: 'Delete',
            splashRadius: 18,
            onPressed: () => onDelete(u),
          ),
        ],
      )),
    ]);
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final colors = {
      'Admin': (const Color(0xFF7C3AED), const Color(0xFFF3E8FF)),
      'ASM': (const Color(0xFF0369A1), const Color(0xFFE0F2FE)),
      'Agency': (const Color(0xFF065F46), const Color(0xFFD1FAE5)),
      'RA': (const Color(0xFF92400E), const Color(0xFFFEF3C7)),
    };
    final c = colors[role] ?? (Colors.grey.shade700, Colors.grey.shade100);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.$2, borderRadius: BorderRadius.circular(12)),
      child: Text(role, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.$1)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isActive ? const Color(0xFF065F46) : const Color(0xFFDC2626),
        ),
      ),
    );
  }
}
