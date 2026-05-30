import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';

class RecordTimerText extends StatelessWidget {
  const RecordTimerText({
    super.key,
    required this.isRecording,
    required this.seconds,
  });
  final bool isRecording;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    String formatDuration(int seconds) {
      final m = (seconds ~/ 60).toString().padLeft(2, '0');
      final s = (seconds % 60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    return Positioned(
      top: -30,
      right: 0,
      left: 0,

      child: AnimatedOpacity(
        opacity: isRecording ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
          ),
          child: CustomText(
            align: TextAlign.center,

            text: formatDuration(seconds),
            style: AppTextStyles.bodyMedium,
          ),
        ),
      ),
    );
  }
}
