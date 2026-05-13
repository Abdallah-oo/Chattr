import 'package:flutter/material.dart';
import 'package:messenger_clone0/core/themes/app_colors.dart';

class CustomSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    EdgeInsetsGeometry? customPadding,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    final SnackBar snackBar = SnackBar(
      content: Row(
        children: [
          if (icon != null) Icon(icon, color: Colors.white, size: 22),
          if (icon != null) const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor ?? Colors.black87,
      behavior: SnackBarBehavior.floating,
      margin:
          customPadding ?? EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: duration,
      action: action,
      elevation: 6,
    );

    ScaffoldMessenger.of(
        Navigator.of(context, rootNavigator: true).overlay!.context,
      )
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  /// Success SnackBar
  static void success(BuildContext context, String message) {
    show(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      backgroundColor: const Color.fromARGB(255, 7, 105, 11),
    );
  }

  ///Error SnackBar
  static void error(
    BuildContext context,
    String message, {
    EdgeInsetsGeometry? padding,
  }) {
    show(
      context,
      message: message,
      customPadding: padding,
      icon: Icons.error_outline_rounded,
      backgroundColor: AppColors.error,
    );
  }

  ///Warning SnackBar
  static void warning(BuildContext context, String message) {
    show(
      context,
      message: message,
      icon: Icons.warning_amber_rounded,
      backgroundColor: Colors.orange.shade700,
    );
  }

  ///Info SnackBar
  static void info(BuildContext context, String message) {
    show(
      context,
      message: message,
      icon: Icons.info_outline_rounded,
      backgroundColor: Colors.blue.shade600,
    );
  }
}
