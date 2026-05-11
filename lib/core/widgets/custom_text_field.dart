import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:messenger_clone0/core/themes/app_colors.dart';

class CustomTextField extends StatefulWidget {
  final bool? secure;
  final String hint;
  final TextInputType? keyboardType;
  final Widget? shape;
  final TextEditingController? controller;
  final String? Function(String?)? validation;
  final Widget? suffixicon;
  final void Function(String)? onchange;
  final Color? color;
  final TextStyle? textStyle;
  final Color? borderColor;
  final Color? cursorColor;
  final int? maxLines;
  final int? minLines;

  const CustomTextField({
    super.key,
    this.secure,
    required this.hint,
    this.keyboardType,
    this.shape,
    this.controller,
    this.validation,
    this.onchange,
    this.color,
    this.suffixicon,
    this.textStyle,
    this.borderColor,
    this.cursorColor,
    this.maxLines,
    this.minLines,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  String? _validatorResult;
  TextDirection _currentDirection = TextDirection.ltr;

  // ---------------- VALIDATION ----------------
  String? _fieldValidation(String? value) {
    if (value == null || value.isEmpty) {
      _validatorResult = "Required field";
    } else {
      _validatorResult = null;
    }
    return _validatorResult;
  }

  // ---------------- TEXT DIRECTION ----------------
  TextDirection _detectDirection(String text) {
    if (text.trim().isEmpty) return TextDirection.ltr;

    return Bidi.detectRtlDirectionality(text)
        ? TextDirection.rtl
        : TextDirection.ltr;
  }

  // ---------------- ON CHANGE HANDLER ----------------
  void _handleChange(String value) {
    final newDirection = _detectDirection(value);

    if (newDirection != _currentDirection) {
      setState(() {
        _currentDirection = newDirection;
      });
    }

    widget.onchange?.call(value);
  }

  // .................Field Decoration .....................
  InputDecoration fieldDecoration() {
    return InputDecoration(
      hintText: widget.hint,
      hintStyle: widget.textStyle,
      suffixIcon: widget.suffixicon,
      prefixIcon: widget.shape,

      filled: true,
      fillColor: widget.color ?? Colors.transparent,
      contentPadding: const EdgeInsets.fromLTRB(10, 5, 5, 5),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: widget.borderColor ?? AppColors.fieldBorder,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: widget.borderColor ?? AppColors.textColor,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color.fromARGB(255, 97, 20, 1),
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color.fromARGB(255, 97, 20, 1),
          width: 2,
        ),
      ),
      errorStyle: const TextStyle(
        color: Color.fromARGB(255, 107, 1, 1),
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    // لو فيه نص جاهز (edit mode)
    final initialText = widget.controller?.text ?? '';
    _currentDirection = _detectDirection(initialText);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: widget.controller,
          minLines: widget.minLines,
          maxLines: widget.secure == true ? 1 : widget.maxLines,
          obscureText: widget.secure ?? false,
          keyboardType: widget.keyboardType ?? TextInputType.text,
          style: widget.textStyle,

          textAlign: TextAlign.start,
          textDirection: _currentDirection,

          cursorColor: widget.cursorColor ?? AppColors.textColor,
          cursorHeight: 15,
          cursorOpacityAnimates: true,

          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: widget.validation ?? _fieldValidation,

          onChanged: _handleChange,

          decoration: fieldDecoration(),
        ),
      ],
    );
  }
}
