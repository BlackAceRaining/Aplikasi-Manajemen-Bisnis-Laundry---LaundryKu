import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF0A5A78);
  static const Color primaryDark = Color(0xFF07435A);
  static const Color primaryLight = Color(0xFFE1F0F5);

  static const Color background = Color(0xFFF4F7F8);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFDCE4E8);
  static const Color borderSubtle = Color(0xFFB9C6CC);

  static const Color textPrimary = Color(0xFF12262E);
  static const Color textSecondary = Color(0xFF55666E);
  static const Color textMuted = Color(0xFF8899A6);

  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // Status colors mapping
  static Color getStatusColor(String status) {
    switch (status) {
      case 'Diterima':
        return const Color(0xFF6366F1); // Indigo
      case 'Ditimbang':
        return const Color(0xFF0EA5E9); // Sky
      case 'Dicuci':
        return const Color(0xFF0284C7); // Light Blue
      case 'Disetrika':
        return const Color(0xFF8B5CF6); // Purple
      case 'Siap':
        return const Color(0xFFF59E0B); // Amber
      case 'Diambil':
        return const Color(0xFF14B8A6); // Teal
      case 'Lunas':
      case 'Selesai':
        return const Color(0xFF10B981); // Emerald
      case 'Tidak Diambil':
      case 'Dibatalkan':
        return const Color(0xFFEF4444); // Red
      default:
        return textSecondary;
    }
  }

  static Color getStatusBgColor(String status) {
    return getStatusColor(status).withValues(alpha: 0.12);
  }
}
