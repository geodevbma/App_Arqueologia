import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PremiumSkeleton extends StatelessWidget {
  const PremiumSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) =>
            Container(
                  height: 88,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                )
                .animate(onPlay: (controller) => controller.repeat())
                .shimmer(duration: 1100.ms),
      ),
    );
  }
}
