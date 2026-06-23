import 'package:flutter/material.dart';

import '../app/theme.dart';

enum BannerTone { success, warning, error, info }

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.icon,
    required this.text,
    required this.tone,
  });

  final IconData icon;
  final String text;
  final BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      BannerTone.success => brandtGreen,
      BannerTone.warning => const Color(0xFFD8A23F),
      BannerTone.error => const Color(0xFF9D3D35),
      BannerTone.info => brandtBlue,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
