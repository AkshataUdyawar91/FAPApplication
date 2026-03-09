import 'package:flutter/material.dart';
import 'nav_item.dart';

/// Shared sidebar widget extracted from Agency dashboard.
/// Used on desktop/tablet viewports for all role-based pages.
class AppSidebar extends StatelessWidget {
  final String userName;
  final String userRole;
  final List<NavItem> navItems;
  final VoidCallback onLogout;
  final bool isCollapsed;

  const AppSidebar({
    super.key,
    required this.userName,
    required this.userRole,
    required this.navItems,
    required this.onLogout,
    this.isCollapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final sidebarWidth = isCollapsed ? 72.0 : 250.0;
    return Container(
      width: sidebarWidth,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
        ),
      ),
      child: Column(
        children: [
          _buildLogo(),
          Divider(height: 1, color: Colors.white.withOpacity(0.2)),
          ...navItems.map((item) => isCollapsed
              ? _buildCollapsedNavItem(item)
              : _buildNavItem(item)),
          const Spacer(),
          if (!isCollapsed) _buildUserInfo(),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Padding(
      padding: EdgeInsets.all(isCollapsed ? 16 : 24),
      child: isCollapsed
          ? Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.business, color: Colors.white, size: 24),
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.business, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Bajaj',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildNavItem(NavItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: item.isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(item.icon, color: Colors.white, size: 20),
        title: Text(
          item.label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: item.isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        dense: true,
        onTap: item.onTap,
      ),
    );
  }

  Widget _buildCollapsedNavItem(NavItem item) {
    return Tooltip(
      message: item.label,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: item.isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          icon: Icon(item.icon, color: Colors.white, size: 20),
          onPressed: item.onTap,
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            radius: 16,
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  userRole,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: isCollapsed
          ? Tooltip(
              message: 'Logout',
              child: IconButton(
                onPressed: onLogout,
                icon: const Icon(Icons.logout, size: 18, color: Colors.white),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.5)),
              ),
            ),
    );
  }
}
