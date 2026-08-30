import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_strings.dart';
import '../../data/models/prayer_day.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/location_service.dart';
import '../../data/services/nafahat_bridge_service.dart';
import '../providers/prayer_provider.dart';
import '../widgets/munib_ultimate_widget.dart';
import '../widgets/prayer_grid_item.dart';
import 'azkar_screen.dart';
import 'notifications_settings_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'widget_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  final String initialAzkarCategory;

  const HomeScreen({
    super.key,
    this.initialIndex = 0,
    this.initialAzkarCategory = 'Morning',
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _nafahatBridge = NafahatBridgeService();

  late int _currentIndex;
  late final PageController _pageController;
  late String _azkarCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex.clamp(0, 3);
    _azkarCategory = widget.initialAzkarCategory;
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeNafahatNavigation());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _consumeNafahatNavigation();
    }
  }

  Future<void> _consumeNafahatNavigation() async {
    final category = await _nafahatBridge.consumePendingAzkarNavigation();
    if (!mounted || category == null) return;
    setState(() => _azkarCategory = category);
    _goTo(1);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final screens = <Widget>[
      const HomeContent(),
      AzkarScreen(
        key: ValueKey('azkar-$_azkarCategory'),
        initialCategoryKey: _azkarCategory,
      ),
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
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_filled),
            label: context.tr('home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.nightlight_round),
            label: context.tr('azkar'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bubble_chart_rounded),
            label: isArabic ? 'نفحات' : 'Nafahat',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            label: context.tr('settings'),
          ),
        ],
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final _locationService = LocationService();
  bool _isAutoFetching = false;
  String? _locationName;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncKnownLocation());
  }

  Future<void> _syncKnownLocation() async {
    if (!mounted) return;
    final provider = context.read<PrayerProvider>();

    if (provider.activeLocationId != null ||
        (provider.currentCity.trim().isNotEmpty &&
            provider.currentCity != 'غير محدد')) {
      return;
    }

    if (!await _locationService.hasGrantedPermission()) return;

    try {
      final location =
          await _locationService.getCurrentLocation(requestPermission: false);
      if (!mounted) return;
      setState(() => _locationName = location.city);
      await provider.updateSetting('currentCity', location.city);
    } catch (_) {}
  }

  Future<bool> _ensureLocationAccess() async {
    var state = await _locationService.accessState();
    if (state == MunibLocationAccess.granted) return true;

    if (state == MunibLocationAccess.serviceDisabled) {
      if (!mounted) return false;
      final openSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(_isArabic ? 'الموقع غير مفعّل' : 'Location is off'),
              content: Text(
                _isArabic
                    ? 'فعّل خدمة الموقع حتى يتمكن منيب من جلب مواقيت الصلاة لمكانك.'
                    : 'Turn on location services so Munib can load prayer times for your area.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(_isArabic ? 'إلغاء' : 'Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(_isArabic ? 'فتح إعدادات الموقع' : 'Open location settings'),
                ),
              ],
            ),
          ) ??
          false;
      if (openSettings) await _locationService.openLocationSettings();
      return false;
    }

    if (state == MunibLocationAccess.deniedForever) {
      return _showPermanentPermissionDialog();
    }

    if (!mounted) return false;
    final shouldRequest = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.my_location_rounded),
            title: Text(_isArabic ? 'السماح بالموقع' : 'Allow location access'),
            content: Text(
              _isArabic
                  ? 'يحتاج منيب موقعك فقط لحساب مواقيت الصلاة الخاصة بمنطقتك. اضغط تفعيل الموقع للمتابعة.'
                  : 'Munib uses your location only to calculate prayer times for your area. Allow access to continue.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_isArabic ? 'ليس الآن' : 'Not now'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.location_on_rounded),
                label: Text(_isArabic ? 'تفعيل الموقع والمتابعة' : 'Enable location and continue'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldRequest) return false;

    state = await _locationService.requestAccess();
    if (state == MunibLocationAccess.granted) return true;
    if (state == MunibLocationAccess.deniedForever) {
      return _showPermanentPermissionDialog();
    }
    return false;
  }

  Future<bool> _showPermanentPermissionDialog() async {
    if (!mounted) return false;
    final openSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(_isArabic ? 'صلاحية الموقع موقوفة' : 'Location permission blocked'),
            content: Text(
              _isArabic
                  ? 'تم منع صلاحية الموقع من النظام. افتح إعدادات منيب وفعّل الموقع ثم أعد المحاولة.'
                  : 'Location permission is blocked by Android. Open Munib settings, allow location, then try again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_isArabic ? 'إلغاء' : 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(_isArabic ? 'فتح الإعدادات' : 'Open settings'),
              ),
            ],
          ),
        ) ??
        false;
    if (openSettings) await _locationService.openAppSettings();
    return false;
  }

  Future<void> _fetchByLocation() async {
    if (_isAutoFetching) return;
    if (!await _ensureLocationAccess()) return;
    if (!mounted) return;

    setState(() => _isAutoFetching = true);
    final provider = context.read<PrayerProvider>();

    try {
      final location =
          await _locationService.getCurrentLocation(requestPermission: false);
      if (mounted) setState(() => _locationName = location.city);

      final result = await AIService().fetchPrayerTimesForLocation(
        location.latitude,
        location.longitude,
        countryCode: location.countryCode,
      );
      if (result.days.isEmpty) throw Exception('empty_prayer_response');

      final parts = location.city.split(',');
      final city = parts.isNotEmpty ? parts.first.trim() : location.city;
      final country =
          parts.length > 1 ? parts.sublist(1).join(',').trim() : '';

      await provider.addLocationImsakia(
        name: city,
        country: country,
        latitude: location.latitude,
        longitude: location.longitude,
        timezone: result.timezone,
        prayers: result.days.map(PrayerDay.fromJson).toList(),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().contains('service_disabled')
          ? context.tr('locationServiceDisabled')
          : context.tr('fetchFailed');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
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
              _EmptyState(
                loading: _isAutoFetching,
                onFetch: _fetchByLocation,
              )
            else if (provider.currentDay == null)
              _ScheduleUnavailableState(
                loading: _isAutoFetching,
                onFetch: _fetchByLocation,
              )
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
    final effectiveLocation =
        locationName.trim().isEmpty || locationName == 'غير محدد'
            ? context.tr('locationUnknown')
            : locationName;

    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
          child: CircleAvatar(
            radius: 23,
            backgroundColor: scheme.primaryContainer,
            foregroundImage: user?.photoURL?.isNotEmpty == true
                ? NetworkImage(user!.photoURL!)
                : null,
            child: user?.photoURL?.isNotEmpty == true
                ? null
                : Icon(Icons.person_rounded, color: scheme.primary),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('hello'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 15,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      effectiveLocation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: context.tr('notifications'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const NotificationsSettingsScreen(),
            ),
          ),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
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
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('nextPrayer'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  _localizedPrayer(context, provider.nextPrayerName),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(Icons.schedule_rounded, color: scheme.primary),
              const SizedBox(height: 6),
              Text(
                provider.timeLeftFormatted,
                textDirection: TextDirection.ltr,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrayerTimesSection extends StatefulWidget {
  final PrayerProvider provider;
  const _PrayerTimesSection({required this.provider});

  @override
  State<_PrayerTimesSection> createState() => _PrayerTimesSectionState();
}

class _PrayerTimesSectionState extends State<_PrayerTimesSection> {
  String? _expandedPrayer;

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final day = provider.currentDay;
    if (day == null) return const SizedBox.shrink();

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final rows = [
      ('fajr', day.fajr, Icons.bedtime_outlined, 'Fajr'),
      ('sunrise', day.sunrise, Icons.wb_twilight_outlined, 'Sunrise'),
      ('dhuhr', day.dhuhr, Icons.wb_sunny_outlined, 'Dhuhr'),
      ('asr', day.asr, Icons.light_mode_outlined, 'Asr'),
      ('maghrib', day.maghrib, Icons.sunny_snowing, 'Maghrib'),
      ('isha', day.isha, Icons.nightlight_outlined, 'Isha'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('todayPrayerTimes'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 14),
        ...rows.map((row) {
          final expanded = _expandedPrayer == row.$4;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PrayerGridItem(
              name: context.tr(row.$1),
              time: provider.formatPrayerTime(row.$2),
              icon: row.$3,
              isActive: provider.nextPrayerName.toLowerCase() ==
                  row.$4.toLowerCase(),
              isExpanded: expanded,
              countdown:
                  expanded ? provider.formattedTimeUntilPrayer(row.$4) : null,
              countdownLabel: isArabic
                  ? 'متبقي حتى ${context.tr(row.$1)}'
                  : 'Until ${context.tr(row.$1)}',
              onTap: () => setState(() {
                _expandedPrayer = expanded ? null : row.$4;
              }),
            ),
          );
        }),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool loading;
  final Future<void> Function() onFetch;

  const _EmptyState({
    required this.loading,
    required this.onFetch,
  });

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return _PrayerDataActionCard(
      icon: Icons.my_location_rounded,
      title: context.tr('noPrayerTimes'),
      body: ar
          ? 'استخدم موقعك لتحميل مواقيت الصلاة تلقائيًا.'
          : 'Use your location to load prayer times automatically.',
      loading: loading,
      onFetch: onFetch,
    );
  }
}

class _ScheduleUnavailableState extends StatelessWidget {
  final bool loading;
  final Future<void> Function() onFetch;

  const _ScheduleUnavailableState({
    required this.loading,
    required this.onFetch,
  });

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return _PrayerDataActionCard(
      icon: Icons.event_busy_rounded,
      title: ar ? 'لا توجد مواقيت لليوم' : 'No prayer times for today',
      body: ar
          ? 'المواقيت المحفوظة لا تغطي تاريخ اليوم. حدّث المواقيت من موقعك.'
          : 'The saved schedule does not cover today. Refresh prayer times from your location.',
      loading: loading,
      onFetch: onFetch,
    );
  }
}

class _PrayerDataActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool loading;
  final Future<void> Function() onFetch;

  const _PrayerDataActionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.loading,
    required this.onFetch,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        children: [
          Icon(icon, size: 64, color: scheme.primary),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          if (loading)
            const CircularProgressIndicator()
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onFetch,
                icon: const Icon(Icons.my_location_rounded),
                label: Text(context.tr('fetchCityTimes')),
              ),
            ),
        ],
      ),
    );
  }
}

String _localizedPrayer(BuildContext context, String prayer) {
  switch (prayer.toLowerCase()) {
    case 'fajr':
      return context.tr('fajr');
    case 'sunrise':
      return context.tr('sunrise');
    case 'dhuhr':
      return context.tr('dhuhr');
    case 'asr':
      return context.tr('asr');
    case 'maghrib':
      return context.tr('maghrib');
    case 'isha':
      return context.tr('isha');
    default:
      return prayer;
  }
}
