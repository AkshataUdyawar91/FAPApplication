import 'package:flutter/material.dart';
import 'nav_item.dart';

/// Shared sidebar widget for all role-based pages.
/// No branding — the top app bar handles that.
/// Contains only nav items, user info, and logout.
class AppSidebar extends StatelessWidget {
  final String userName;
  final String userRole;
  final List<NavItem> navItems;
  final VoidCallback onLogout;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  static const double expandedWidth = 240.0;
  static const double collapsedWidth = 64.0;

  const AppSidebar({
    super.key,
    required this.userName,
    required this.userRole,
    required this.navItems,
    required this.onLogout,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  double get _width => isCollapsed ? collapsedWidth : expandedWidth;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: _width,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF003087), Color(0xFF1E40AF)],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 4),
          if (onToggleCollapse != null)
            Align(
              alignment: isCollapsed ? Alignment.center : Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 10, vertical: 4),
                child: IconButton(
                  icon: Icon(
                    isCollapsed ? Icons.menu : Icons.menu_open,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: onToggleCollapse,
                  tooltip: isCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
                  splashRadius: 20,
                ),
              ),
            ),
          Divider(height: 1, color: Colors.white.withOpacity(0.15)),
          const SizedBox(height: 4),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: navItems
                  .map<Widget>((item) => isCollapsed
                      ? _buildCollapsedNavItem(item)
                      : _buildNavItem(item))
                  .toList(),
            ),
          ),
          if (!isCollapsed) _buildUserInfo(),
          _buildLogoutButton(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildNavItem(NavItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: item.isActive ? Colors.white.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(item.icon, color: Colors.white, size: 20),
        title: Text(
          item.label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white,
            fontWeight: item.isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        dense: true,
        visualDensity: const VisualDensity(vertical: -1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: item.onTap,
      ),
    );
  }

  Widget _buildCollapsedNavItem(NavItem item) {
    return Tooltip(
      message: item.label,
      preferBelow: false,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: item.isActive ? Colors.white.withOpacity(0.15) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(item.icon, color: Colors.white, size: 20),
          onPressed: item.onTap,
          splashRadius: 20,
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            radius: 14,
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Color(0xFF003087),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  userRole,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    if (isCollapsed) {
      return Tooltip(
        message: 'Logout',
        child: IconButton(
          onPressed: onLogout,
          icon: const Icon(Icons.logout, size: 18, color: Colors.white70),
          splashRadius: 18,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout, size: 16),
          label: const Text('Logout', style: TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: BorderSide(color: Colors.white.withOpacity(0.2)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }
}
