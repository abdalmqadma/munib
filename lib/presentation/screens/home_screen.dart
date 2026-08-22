import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_strings.dart';
import '../../data/models/prayer_day.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/location_service.dart';
import '../providers/prayer_provider.dart';
import '../widgets/munib_ultimate_widget.dart';
import '../widgets/prayer_grid_item.dart';
import 'azkar_screen.dart';
import 'notifications_settings_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'upload_screen.dart';
import 'widget_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeContent(onStartTraining: () => _goTo(2)),
      const AzkarScreen(),
      const WidgetPreviewScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentIndex = index),
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _goTo,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home_filled), label: context.tr('home')),
          BottomNavigationBarItem(icon: const Icon(Icons.nightlight_round), label: context.tr('azkar')),
          BottomNavigationBarItem(icon: const Icon(Icons.auto_awesome_outlined), label: context.tr('training')),
          BottomNavigationBarItem(icon: const Icon(Icons.settings_outlined), label: context.tr('settings')),
        ],
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  final VoidCallback onStartTraining;
  const HomeContent({super.key, required this.onStartTraining});
  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  bool _isAutoFetching = false;
  String? _locationName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showCoachIntroOnce());
  }

  Future<void> _showCoachIntroOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('prayerCoachIntroShown') ?? false) return;
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    await prefs.setBool('prayerCoachIntroShown', true);
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final scheme = theme.colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.accessibility_new_rounded, color: scheme.primary, size: 32),
                ),
                const SizedBox(height: 16),
                Text(context.tr('newFeature'), style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary)),
                const SizedBox(height: 6),
                Text(context.tr('coachIntroTitle'), textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 10),
                Text(context.tr('coachIntroBody'), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      widget.onStartTraining();
                    },
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: Text(context.tr('tryNow')),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text(context.tr('later')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _fetchByLocation() async {
    if (_isAutoFetching) return;
    setState(() => _isAutoFetching = true);
    final provider = context.read<PrayerProvider>();
    try {
      final location = await LocationService().getCurrentLocation();
      if (mounted) setState(() => _locationName = location.city);
      final data = await AIService().fetchPrayerTimesByCoordinates(
        location.latitude,
        location.longitude,
      );
      if (data.isEmpty) throw Exception('empty_prayer_response');
      await provider.setMonthlyPrayers(data.map(PrayerDay.fromJson).toList());
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().contains('denied_forever')
          ? context.tr('locationPermissionForever')
          : e.toString().contains('service_disabled')
              ? context.tr('locationServiceDisabled')
              : e.toString().contains('permission_denied')
                  ? context.tr('locationPermissionDenied')
                  : context.tr('fetchFailed');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isAutoFetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrayerProvider>();
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetchByLocation,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            _HomeHeader(locationName: _locationName ?? provider.currentCity),
            const SizedBox(height: 24),
            if (provider.monthlyPrayers.isEmpty)
              _EmptyState(loading: _isAutoFetching, onFetch: _fetchByLocation)
            else ...[
              const MunibUltimateWidget(),
              const SizedBox(height: 24),
              _NextPrayerSummary(provider: provider),
              const SizedBox(height: 24),
              _PrayerTimesSection(provider: provider),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final String locationName;
  const _HomeHeader({required this.locationName});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final scheme = Theme.of(context).colorScheme;
    final effectiveLocation = locationName.trim().isEmpty || locationName == 'غير محدد'
        ? context.tr('locationUnknown') : locationName;
    return Row(children: [
      InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
        child: CircleAvatar(
          radius: 23,
          backgroundColor: scheme.primaryContainer,
          foregroundImage: user?.photoURL?.isNotEmpty == true ? NetworkImage(user!.photoURL!) : null,
          child: user?.photoURL?.isNotEmpty == true ? null : Icon(Icons.person_rounded, color: scheme.primary),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.tr('hello'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 3),
        Row(children: [
          Icon(Icons.location_on_outlined, size: 15, color: scheme.primary),
          const SizedBox(width: 4),
          Flexible(child: Text(effectiveLocation, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)),
        ]),
      ])),
      IconButton.filledTonal(
        tooltip: context.tr('notifications'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsSettingsScreen())),
        icon: const Icon(Icons.notifications_none_rounded),
      ),
    ]);
  }
}

class _NextPrayerSummary extends StatelessWidget {
  final PrayerProvider provider;
  const _NextPrayerSummary({required this.provider});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(28), border: Border.all(color: scheme.outline)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('nextPrayer'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(_localizedPrayer(context, provider.nextPrayerName), style: Theme.of(context).textTheme.headlineSmall),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Icon(Icons.schedule_rounded, color: scheme.primary),
          const SizedBox(height: 6),
          Text(provider.timeLeftFormatted, textDirection: TextDirection.ltr, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      ]),
    );
  }
}

class _PrayerTimesSection extends StatelessWidget {
  final PrayerProvider provider;
  const _PrayerTimesSection({required this.provider});
  @override
  Widget build(BuildContext context) {
    final day = provider.currentDay;
    if (day == null) return const SizedBox.shrink();
    final rows = [
      ('fajr', day.fajr, Icons.bedtime_outlined, 'Fajr'),
      ('sunrise', day.sunrise, Icons.wb_twilight_outlined, 'Sunrise'),
      ('dhuhr', day.dhuhr, Icons.wb_sunny_outlined, 'Dhuhr'),
      ('asr', day.asr, Icons.light_mode_outlined, 'Asr'),
      ('maghrib', day.maghrib, Icons.sunny_snowing, 'Maghrib'),
      ('isha', day.isha, Icons.nightlight_outlined, 'Isha'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.tr('todayPrayerTimes'), style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 14),
      ...rows.map((row) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: PrayerGridItem(
          name: context.tr(row.$1),
          time: provider.formatPrayerTime(row.$2),
          icon: row.$3,
          isActive: provider.nextPrayerName.toLowerCase() == row.$4.toLowerCase(),
        ),
      )),
    ]);
  }
}

class _EmptyState extends StatelessWidget {
  final bool loading;
  final Future<void> Function() onFetch;
  const _EmptyState({required this.loading, required this.onFetch});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(28), border: Border.all(color: scheme.outline)),
      child: Column(children: [
        Icon(Icons.my_location_rounded, size: 64, color: scheme.primary),
        const SizedBox(height: 18),
        Text(context.tr('noPrayerTimes'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        Text(context.tr('uploadOrLocation'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 24),
        if (loading) const CircularProgressIndicator() else ...[
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onFetch, icon: const Icon(Icons.my_location_rounded), label: Text(context.tr('fetchCityTimes')))),
          const SizedBox(height: 12),
          Text(context.tr('or'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadScreen())),
            icon: const Icon(Icons.upload_file_rounded), label: Text(context.tr('uploadImsakia')),
          )),
        ],
      ]),
    );
  }
}

String _localizedPrayer(BuildContext context, String prayer) {
  switch (prayer.toLowerCase()) {
    case 'fajr': return context.tr('fajr');
    case 'sunrise': return context.tr('sunrise');
    case 'dhuhr': return context.tr('dhuhr');
    case 'asr': return context.tr('asr');
    case 'maghrib': return context.tr('maghrib');
    case 'isha': return context.tr('isha');
    default: return prayer;
  }
}
