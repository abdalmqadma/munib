import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_strings.dart';
import '../providers/prayer_provider.dart';
import 'location_imsakia_screen.dart';
import 'upload_screen.dart';

class ImsakiaSettingsScreen extends StatelessWidget {
  const ImsakiaSettingsScreen({super.key});

  bool _isArabic(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar';

  String _t(BuildContext context, String ar, String en) =>
      _isArabic(context) ? ar : en;

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
          Text(
            _t(context, 'مواقع الإمساكية', 'Imsakia locations'),
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            _t(
              context,
              'اضغط على مدينة لتفعيلها، واسحب المقبض لتغيير أولوية ظهورها.',
              'Tap a city to activate it, then drag the handle to change its display priority.',
            ),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (provider.savedLocations.isNotEmpty)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: provider.savedLocations.length,
              onReorder: provider.reorderSavedLocations,
              itemBuilder: (context, index) {
                final location = provider.savedLocations[index];
                final active = provider.activeLocationId == location.id;
                return Padding(
                  key: ValueKey(location.id),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: active
                          ? scheme.primary.withValues(alpha: .10)
                          : scheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active ? scheme.primary : scheme.outline,
                        width: active ? 1.4 : 1,
                      ),
                    ),
                    child: ListTile(
                      onTap: () => provider.activateSavedLocation(location.id),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: Icon(
                        active
                            ? Icons.radio_button_checked_rounded
                            : Icons.location_on_outlined,
                        color: active
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      title: Text(
                        location.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: active
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        active
                            ? _t(
                                context,
                                'الإمساكية النشطة • الأولوية ${index + 1}',
                                'Active Imsakia • Priority ${index + 1}',
                              )
                            : _t(
                                context,
                                'اضغط للتفعيل • الأولوية ${index + 1}',
                                'Tap to activate • Priority ${index + 1}',
                              ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (provider.savedLocations.length > 1)
                            IconButton(
                              tooltip: _t(
                                context,
                                'حذف الموقع',
                                'Remove location',
                              ),
                              onPressed: () => provider.removeSavedLocation(
                                location.id,
                              ),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          if (provider.savedLocations.length > 1)
                            ReorderableDragStartListener(
                              index: index,
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Icon(
                                  Icons.drag_handle_rounded,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LocationImsakiaScreen()),
              ),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(_t(context, 'إضافة موقع من أي مكان في العالم', 'Add a location anywhere in the world')),
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
