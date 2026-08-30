import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/prayer_day.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/place_search_service.dart';
import '../providers/prayer_provider.dart';

class LocationImsakiaScreen extends StatefulWidget {
  const LocationImsakiaScreen({super.key});

  @override
  State<LocationImsakiaScreen> createState() => _LocationImsakiaScreenState();
}

class _LocationImsakiaScreenState extends State<LocationImsakiaScreen> {
  final _controller = TextEditingController();
  final _searchService = PlaceSearchService();
  final _aiService = AIService();

  Timer? _debounce;
  int _searchGeneration = 0;
  bool _searching = false;
  bool _adding = false;
  String? _error;
  List<MunibPlaceSearchResult> _results = const [];

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String t(String ar, String en) => _isArabic ? ar : en;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      _searchGeneration++;
      setState(() {
        _searching = false;
        _results = const [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 320), () => _search(query));
  }

  Future<void> _search([String? rawQuery]) async {
    final query = (rawQuery ?? _controller.text).trim();
    if (query.isEmpty) return;

    final generation = ++_searchGeneration;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final result = await _searchService.search(query);
      if (!mounted || generation != _searchGeneration) return;
      setState(() => _results = result);
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() => _error = t(
            'تعذر البحث عن الأماكن. تحقق من الإنترنت وحاول مرة أخرى.',
            'Could not search places. Check your connection and try again.',
          ));
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _add(MunibPlaceSearchResult place) async {
    if (_adding) return;
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      final result = await _aiService.fetchPrayerTimesForLocation(
        place.latitude,
        place.longitude,
        countryCode: place.countryCode,
      );
      if (result.days.isEmpty) throw Exception('empty_times');
      final prayers = result.days.map(PrayerDay.fromJson).toList();
      if (!mounted) return;
      await context.read<PrayerProvider>().addLocationImsakia(
            name: place.city,
            country: place.country,
            latitude: place.latitude,
            longitude: place.longitude,
            timezone: result.timezone,
            prayers: prayers,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = t(
              'تعذر تحميل إمساكية هذا الموقع الآن.',
              'Could not load prayer times for this place right now.',
            ));
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t('إضافة موقع', 'Add location'))),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                onSubmitted: (value) {
                  _debounce?.cancel();
                  _search(value);
                },
                decoration: InputDecoration(
                  hintText:
                      t('ابحث عن مدينة أو دولة...', 'Search for a city or country...'),
                  prefixIcon: const Icon(Icons.public_rounded),
                  suffixIcon: IconButton(
                    onPressed: () {
                      _debounce?.cancel();
                      _search();
                    },
                    icon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
            ),
            if (_searching || _adding)
              const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: _results.isEmpty && !_searching
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.travel_explore_rounded,
                                size: 58, color: scheme.primary),
                            const SizedBox(height: 16),
                            Text(
                              _controller.text.trim().isEmpty
                                  ? t(
                                      'ابدأ بكتابة اسم المدينة وستظهر النتائج مباشرة.',
                                      'Start typing a city name and results will appear automatically.',
                                    )
                                  : t(
                                      'لا توجد نتائج مطابقة حتى الآن.',
                                      'No matching results yet.',
                                    ),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final place = _results[index];
                        return Material(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _adding ? null : () => _add(place),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: scheme.primary.withValues(alpha: .12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(Icons.location_on_outlined,
                                        color: scheme.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          [place.city, place.country]
                                              .where((e) => e.trim().isNotEmpty)
                                              .join(', '),
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          place.displayName,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.add_circle_outline_rounded),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
