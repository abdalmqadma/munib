import 'package:flutter_test/flutter_test.dart';
import 'package:munib/features/prayer_times/data/models/prayer_day.dart';
import 'package:munib/features/prayer_times/data/models/saved_imsakia_location.dart';
import 'package:munib/features/prayer_times/data/saved_imsakia_location_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const store = SavedImsakiaLocationStore();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('round trips saved locations without losing prayer data', () async {
    final location = SavedImsakiaLocation(
      id: '31.50000:34.45000',
      name: 'Gaza',
      country: 'Palestine',
      latitude: 31.5,
      longitude: 34.45,
      timezone: 'Asia/Gaza',
      prayers: [
        PrayerDay(
          date: '2026-08-30',
          fajr: '04:30',
          sunrise: '05:55',
          dhuhr: '12:00',
          asr: '15:30',
          maghrib: '18:20',
          isha: '19:45',
        ),
      ],
    );

    await store.save(
      locations: [location],
      activeLocationId: location.id,
    );

    final loaded = await store.load();
    expect(loaded, hasLength(1));
    expect(loaded.single.id, location.id);
    expect(loaded.single.label, 'Gaza, Palestine');
    expect(loaded.single.prayers.single.maghrib, '18:20');
  });

  test('returns an empty collection for corrupted persisted JSON', () async {
    SharedPreferences.setMockInitialValues({
      'savedImsakiaLocationsV1': '{broken-json',
    });

    expect(await store.load(), isEmpty);
  });

  test('clears the active location key when no location is active', () async {
    SharedPreferences.setMockInitialValues({
      'activeImsakiaLocationId': 'old-location',
    });

    await store.save(locations: const [], activeLocationId: null);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('activeImsakiaLocationId'), isNull);
  });
}
