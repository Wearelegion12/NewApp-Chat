// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // Modern React-inspired color palette
  static const Color primary = Color(0xFF3B82F6); // React blue
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF2563EB);

  static const Color success = Color(0xFF10B981); // Emerald
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Red
  static const Color info = Color(0xFF8B5CF6); // Purple

  // Grayscale
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);
  static const Color successDark = Color(0xFF0B8A4F);

  // Text colors
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);

  // Background & Surface
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color borderLight = Color(0xFFE2E8F0);

  // Hover overlay
  static const Color hoverOverlay = Color(0x0F3B82F6);

  // Common decorations
  static BoxDecoration cardDecoration = BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: borderLight),
    boxShadow: [
      BoxShadow(
        color: borderLight.withOpacity(0.3),
        blurRadius: 12,
        offset: const Offset(0, 4),
        spreadRadius: -4,
      ),
    ],
  );

  static BoxDecoration avatarDecoration(Color color) {
    return BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.2),
          blurRadius: 12,
          spreadRadius: 0,
        ),
      ],
    );
  }

  // Snackbar styling
  static SnackBar createSnackBar(String message, Color color,
      {IconData? icon}) {
    return SnackBar(
      content: Row(
        children: [
          Icon(icon ?? Icons.check_circle, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    );
  }
}
