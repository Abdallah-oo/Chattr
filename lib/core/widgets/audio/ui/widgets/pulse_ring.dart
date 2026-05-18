import 'package:flutter/material.dart';

class PulseRing extends StatelessWidget {
  const PulseRing({super.key, required this.pulseAnim});
  final Animation<double> pulseAnim;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      left: 0,
      child: Transform.scale(
        scale: pulseAnim.value,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.red.withOpacity(0.4 * (2 - pulseAnim.value)),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}
