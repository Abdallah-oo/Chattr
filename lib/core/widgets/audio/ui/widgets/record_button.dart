import 'package:flutter/material.dart';

class RecordButton extends StatelessWidget {
  const RecordButton({super.key, required this.scaleAnim, required this.isRecording});
  final Animation<double> scaleAnim;
  final bool isRecording;
  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      left: 0,
      child: Transform.scale(
        scale: scaleAnim.value,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isRecording
                ? const LinearGradient(
                    colors: [Color(0xFFFF4444), Color(0xFFCC0000)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            boxShadow: [
              BoxShadow(
                color: isRecording
                    ? Colors.red.withOpacity(0.5)
                    : Colors.blue.withOpacity(0.4),
                blurRadius: isRecording ? 12 : 6,
                spreadRadius: isRecording ? 2 : 0,
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isRecording ? Icons.stop_rounded : Icons.mic,
              key: ValueKey(isRecording),
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
