import 'package:flutter/material.dart';

/// App color palette matching Figma design
class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF0066FF); // Blue 600
  static const Color primaryDark = Color(0xFF0052CC);
  static const Color primaryLight = Color(0xFF3385FF);
  
  // Background Colors
  static const Color background = Color(0xFFF9FAFB); // Gray 50
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color inputBackground = Color(0xFFF3F4F6); // Gray 100
  
  // Text Colors
  static const Color textPrimary = Color(0xFF111827); // Gray 900
  static const Color textSecondary = Color(0xFF6B7280); // Gray 500
  static const Color textTertiary = Color(0xFF9CA3AF); // Gray 400
  
  // Border Colors
  static const Color border = Color(0xFFE5E7EB); // Gray 200
  static const Color borderLight = Color(0xFFF3F4F6); // Gray 100
  
  // Status Colors - Pending
  static const Color pendingBackground = Color(0xFFFEF3C7); // Yellow 100
  static const Color pendingText = Color(0xFF92400E); // Yellow 900
  static const Color pendingBorder = Color(0xFFFDE68A); // Yellow 200
  
  // Status Colors - Under Review
  static const Color reviewBackground = Color(0xFFDBEAFE); // Blue 100
  static const Color reviewText = Color(0xFF1E40AF); // Blue 800
  static const Color reviewBorder = Color(0xFFBFDBFE); // Blue 200
  
  // Status Colors - Approved
  static const Color approvedBackground = Color(0xFFD1FAE5); // Green 100
  static const Color approvedText = Color(0xFF065F46); // Green 800
  static const Color approvedBorder = Color(0xFFA7F3D0); // Green 200
  
  // Status Colors - Rejected
  static const Color rejectedBackground = Color(0xFFFEE2E2); // Red 100
  static const Color rejectedText = Color(0xFF991B1B); // Red 800
  static const Color rejectedBorder = Color(0xFFFECACA); // Red 200
  
  // Gradient Colors
  static const List<Color> gradientBlue = [
    Color(0xFFEFF6FF), // Blue 50
    Color(0xFFFFFFFF), // White
    Color(0xFFEFF6FF), // Blue 50
  ];
  
  // Shadow Colors
  static const Color shadow = Color(0x1A000000); // 10% black
  static const Color shadowLight = Color(0x0D000000); // 5% black
}
