import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:messenger_clone0/core/themes/app_colors.dart';

class CustomText extends StatelessWidget {
  const CustomText({
    super.key,
    this.color,
    required this.size,
    required this.text,
    this.fontWeight,
    this.align,
    this.minFontSize,
    this.maxLines,
    this.fontFamily,
    this.line,
    this.letterSpacing,
  });
  final Color? color;
  final double size;
  final String text;
  final FontWeight? fontWeight;
  final String? fontFamily;
  final TextAlign? align;
  final double? minFontSize;
  final int? maxLines;
  final TextDecoration? line;
  final double? letterSpacing;

  @override
  Widget build(BuildContext context) {
    return AutoSizeText(
      overflow: TextOverflow.ellipsis,
      text,
      textAlign: align,
      textDirection: Bidi.detectRtlDirectionality(text)
          ? TextDirection.rtl
          : TextDirection.ltr,
      style: TextStyle(
        letterSpacing: letterSpacing,
        color: color ?? AppColors.textColor,
        fontSize: size,
        fontWeight: fontWeight,
        fontFamily: fontFamily,
        decoration: line,
      ),
      maxLines: maxLines ?? 1,
      minFontSize: minFontSize ?? 8,
    );
  }
}
