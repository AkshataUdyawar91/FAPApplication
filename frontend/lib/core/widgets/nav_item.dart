import 'package:flutter/material.dart';

/// Model class for navigation items used in sidebar and drawer.
class NavItem {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const NavItem({
    required this.icon,
    required this.label,
    this.isActive = false,
    required this.onTap,
  });
}
