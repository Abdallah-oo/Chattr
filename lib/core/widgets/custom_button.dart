import 'package:flutter/material.dart';
import 'package:messenger_clone0/core/themes/app_colors.dart';

class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.raduis,
    this.onPressed,
    this.padding,
    required this.child,
    this.color,
    this.borderSide,
    this.elevetion,
    this.borderRadiusGeometry,
  });
  final void Function()? onPressed;

  final EdgeInsetsGeometry? padding;
  final Widget child;
  final double raduis;
  final Color? color;
  final BorderSide? borderSide;
  final double? elevetion;
  final BorderRadiusGeometry? borderRadiusGeometry;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ButtonStyle(
        elevation: WidgetStateProperty.all(elevetion),

        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return color ?? AppColors.primaryButton;
          }
          return color ?? AppColors.primaryButton;
        }),

        padding: WidgetStateProperty.all(
          padding ?? EdgeInsets.symmetric(vertical: 10),
        ),

        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: borderRadiusGeometry ?? BorderRadius.circular(raduis),
            side: borderSide ?? BorderSide.none,
          ),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: WidgetStateProperty.all(const Size(0, 0)),
      ),
      child: child,
    );
  }
}
