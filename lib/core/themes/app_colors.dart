import 'package:flutter/material.dart';

class AppColors {
  static const Color textColor = Color(0xFFE0E0E0);
  static const Color text2Color = Color(0xFFCECECC);
  static const Color paleColor = Color(0x8AFFFFFF);
  static const Color titleColor = Color(0xFFE0E0E0);
  static const Color primaryButton = Color(0xFF2A6BE6);
  static const Color secondaryButton = Color(0xFF03DAC6);
  static const Color fieldBorder = Color(0xFF5A5A58);
  static const Color groundColor = Color(0xFF121212);
  static const Color border = Color(0xFF333333);
  static const Color cancleColor = Color(0xFFCE1E12);
  static const Color black = Color(0xFF1A1A1A);


  // SHADOWS 


  static final List<BoxShadow> shadowSm = [
    BoxShadow(
      color: black.withOpacity(0.05),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static final List<BoxShadow> shadowMd = [
    BoxShadow(
      color: black.withOpacity(0.08),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> shadowLg = [
    BoxShadow(
      color: black.withOpacity(0.12),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
}
