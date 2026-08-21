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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isActive ? scheme.primaryContainer : scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? scheme.primary.withValues(alpha: 0.55) : scheme.outline,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: isActive
                  ? scheme.primary.withValues(alpha: 0.12)
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: isActive ? scheme.primary : scheme.onSurfaceVariant,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.titleMedium?.copyWith(
                color: isActive ? scheme.primary : scheme.onSurface,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            time,
            textDirection: TextDirection.ltr,
            style: theme.textTheme.titleMedium?.copyWith(
              color: isActive ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
