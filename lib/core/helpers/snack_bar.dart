import 'package:flutter/material.dart';
import 'package:messenger_clone0/core/themes/app_colors.dart';
import 'package:messenger_clone0/core/themes/app_text_styles.dart';
import 'package:messenger_clone0/core/widgets/custom_text.dart';

class CustomSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    EdgeInsetsGeometry? customPadding,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    final SnackBar snackBar =
     SnackBar(
      content: Row(
        children: [
          if (icon != null) Icon(icon, color: Colors.white, size: 22),
          if (icon != null) const SizedBox(width: 10),
          Expanded(
            child: CustomText(text: message, style: AppTextStyles.bodyMedium),
          ),
        ],
      ),
      backgroundColor: backgroundColor ?? Colors.black87,
      behavior: SnackBarBehavior.floating,
      margin: customPadding ?? EdgeInsets.fromLTRB(17, 0, 17, 100),
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
