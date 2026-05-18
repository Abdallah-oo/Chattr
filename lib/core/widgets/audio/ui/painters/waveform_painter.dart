import 'dart:math' as math;
import 'package:flutter/material.dart';
class WaveformPainter extends CustomPainter {
  final double progress;
  final double animValue;
  final bool isPlaying;

  WaveformPainter({
    required this.progress,
    required this.animValue,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 28;
    final barWidth = (size.width - (barCount - 1) * 2.5) / barCount;

    // أطوال الموجات - تقليد شكل واتساب
    final heights = List.generate(barCount, (i) {
      final base = math.sin(i * 0.8) * 0.4 +
          math.sin(i * 0.3) * 0.3 +
          math.cos(i * 1.2) * 0.2 +
          0.55;
      return (base.clamp(0.15, 0.95));
    });

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + 2.5);
      final barProgress = i / barCount;

      // ✅ animation للبارات اللي بتشتغل
      double heightMultiplier = heights[i];
      if (isPlaying && barProgress <= progress) {
        final wave = math.sin(
          (animValue * 2 * math.pi) + (i * 0.4),
        );
        heightMultiplier = (heights[i] + wave * 0.15).clamp(0.1, 1.0);
      }

      final barHeight = size.height * heightMultiplier;
      final top = (size.height - barHeight) / 2;

      final isPlayed = barProgress <= progress;

      final paint = Paint()
        ..color = isPlayed
            ? Colors.white
            : Colors.white.withOpacity(0.3)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.fill;

      final rRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, barWidth, barHeight),
        Radius.circular(barWidth / 2),
      );

      canvas.drawRRect(rRect, paint);
    }
  }

  @override
  bool shouldRepaint(WaveformPainter old) =>
      old.progress != progress ||
      old.animValue != animValue ||
      old.isPlaying != isPlaying;
}