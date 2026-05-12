import 'package:flutter/material.dart';

abstract class AppColors {
  // ===================== Brand =====================

  static const Color primary = Color(0xFF2A6BE6);
  static const Color secondary = Color(0xFF03DAC6);

  // ===================== Background =====================

  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1A1A1A);

  // ===================== Text =====================

  static const Color textPrimary = Color(0xFFE0E0E0);
  static const Color textSecondary = Color(0xFFCECECC);
  static const Color textHint = Color(0x8AFFFFFF);

  // ===================== Borders =====================

  static const Color border = Color(0xFF333333);
  static const Color inputBorder = Color(0xFF5A5A58);

  // ===================== Status =====================

  static const Color error = Color(0xFFCE1E12);
  

  // ===================== Shadows =====================

  static final List<BoxShadow> shadowSm = [
    BoxShadow(
      color: surface.withOpacity(0.05),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static final List<BoxShadow> shadowMd = [
    BoxShadow(
      color: surface.withOpacity(0.08),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> shadowLg = [
    BoxShadow(
      color: surface.withOpacity(0.12),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
}
