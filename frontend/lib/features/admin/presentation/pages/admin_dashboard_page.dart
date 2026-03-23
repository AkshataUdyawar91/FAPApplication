import 'package:flutter/material.dart';
import '../../../../core/widgets/app_sidebar.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../core/widgets/nav_item.dart';
import 'supplier_agency_master_page.dart';
import 'supplier_po_page.dart';
import 'state_city_master_page.dart';
import 'user_management_page.dart';
import 'dealer_master_page.dart';
import 'ra_ch_state_mapping_page.dart';
import 'enquiry_dump_page.dart';
import 'sap_logs_page.dart';
import 'email_logs_page.dart';

class AdminDashboardPage extends StatefulWidget {
  final String token;
  final String userName;
  final VoidCallback? onLogout;

  const AdminDashboardPage({
    super.key,
    required this.token,
    required this.userName,
    this.onLogout,
  });

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;

  final List<_AdminMenuItem> _menuItems = const [
    _AdminMenuItem(icon: Icons.business, label: 'Agency Master'),
    _AdminMenuItem(icon: Icons.receipt_long, label: 'Supplier PO'),
    _AdminMenuItem(icon: Icons.map_outlined, label: 'State City Master'),
    _AdminMenuItem(icon: Icons.manage_accounts, label: 'User Master'),
    _AdminMenuItem(icon: Icons.store, label: 'Dealer Master'),
    _AdminMenuItem(icon: Icons.account_tree_outlined, label: 'State Hierarchy'),
    _AdminMenuItem(icon: Icons.download_outlined, label: 'Enquiry Data'),
    _AdminMenuItem(icon: Icons.email_outlined, label: 'Email Logs'),
    _AdminMenuItem(icon: Icons.sync_outlined, label: 'SAP Logs'),
  ];

  Widget _buildPage(int index) {
    switch (index) {
      case 0: return SupplierAgencyMasterPage(key: ValueKey('page-$index'), token: widget.token);
      case 1: return SupplierPoPage(key: ValueKey('page-$index'), token: widget.token);
      case 2: return StateCityMasterPage(key: ValueKey('page-$index'), token: widget.token);
      case 3: return UserManagementPage(key: ValueKey('page-$index'), token: widget.token);
      case 4: return DealerMasterPage(key: ValueKey('page-$index'), token: widget.token);
      case 5: return RaChStateMappingPage(key: ValueKey('page-$index'), token: widget.token);
      case 6: return EnquiryDumpPage(key: ValueKey('page-$index'), token: widget.token);
      case 7: return EmailLogsPage(key: ValueKey('page-$index'), token: widget.token);
      case 8: return SapLogsPage(key: ValueKey('page-$index'), token: widget.token);
      default: return SupplierAgencyMasterPage(key: ValueKey('page-$index'), token: widget.token);
    }
  }

  List<NavItem> _buildNavItems() {
    return List.generate(_menuItems.length, (i) {
      final item = _menuItems[i];
      return NavItem(
        icon: item.icon,
        label: item.label,
        isActive: _selectedIndex == i,
        onTap: () => setState(() => _selectedIndex = i),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final navItems = _buildNavItems();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('FieldIQ — Admin Panel',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: const Color(0xFF003087),
        foregroundColor: Colors.white,
        leading: isDesktop ? null : Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      drawer: isDesktop
          ? null
          : AppDrawer(
              userName: widget.userName,
              userRole: 'Admin',
              navItems: navItems,
              onLogout: widget.onLogout ?? () {},
            ),
      body: Row(
        children: [
          if (isDesktop)
            AppSidebar(
              userName: widget.userName,
              userRole: 'Admin',
              navItems: navItems,
              onLogout: widget.onLogout ?? () {},
              isCollapsed: _isSidebarCollapsed,
              onToggleCollapse: () =>
                  setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
            ),
          Expanded(child: _buildPage(_selectedIndex)),
        ],
      ),
    );
  }
}

class _AdminMenuItem {
  final IconData icon;
  final String label;
  const _AdminMenuItem({required this.icon, required this.label});
}
