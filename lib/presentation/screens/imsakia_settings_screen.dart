import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_strings.dart';
import '../providers/prayer_provider.dart';
import 'upload_screen.dart';

class ImsakiaSettingsScreen extends StatelessWidget {
  const ImsakiaSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrayerProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('imsakiaSettings'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.outline),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.schedule_rounded, color: scheme.primary),
                  ),
                  title: Text(context.tr('timeFormat'), style: theme.textTheme.titleMedium),
                  subtitle: Text(
                    provider.use24HourFormat
                        ? context.tr('timeFormat24')
                        : context.tr('timeFormat12'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SegmentedButton<bool>(
                    showSelectedIcon: true,
                    segments: [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text(context.tr('timeFormat12')),
                        icon: const Icon(Icons.access_time_rounded),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text(context.tr('timeFormat24')),
                        icon: const Icon(Icons.schedule_rounded),
                      ),
                    ],
                    selected: {provider.use24HourFormat},
                    onSelectionChanged: (selection) {
                      provider.setUse24HourFormat(selection.first);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.outline),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UploadScreen()),
              ),
              leading: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.cloud_upload_outlined, color: scheme.primary),
              ),
              title: Text(context.tr('changeImsakia'), style: theme.textTheme.titleMedium),
              subtitle: Text(context.tr('changeImsakiaHint'), style: theme.textTheme.bodySmall),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
