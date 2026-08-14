import 'package:flutter/material.dart';

class PrayerGridItem extends StatelessWidget {
  final String name;
  final String time;
  final IconData icon;
  final bool isActive;

  const PrayerGridItem({
    super.key,
    required this.name,
    required this.time,
    required this.icon,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isActive ? Colors.blue.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Elegant Icon replacing primitive emojis
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive ? Colors.blue.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.02),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.blue : Colors.white38,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: TextStyle(
              color: isActive ? Colors.blue : Colors.white70,
              fontSize: 16,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: TextStyle(
              color: isActive ? Colors.blue.withValues(alpha: 0.7) : Colors.white24,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
