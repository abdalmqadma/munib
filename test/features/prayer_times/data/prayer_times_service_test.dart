import 'package:flutter_test/flutter_test.dart';
import 'package:munib/features/prayer_times/data/prayer_times_service.dart';

void main() {
  group('PrayerCalculationProfile', () {
    test('uses the Palestine profile for PS', () {
      final profile = PrayerCalculationProfile.forCountry('PS');

      expect(profile.method, 5);
      expect(profile.school, 0);
      expect(profile.tune, '0,0,0,-1,-1,2,0,-1,0');
    });

    test('detects Gaza profile when reverse geocoding is unavailable', () {
      final profile = PrayerCalculationProfile.forLocation(
        latitude: 31.42,
        longitude: 34.38,
      );

      expect(profile.method, 5);
      expect(profile.tune, '0,0,0,-1,-1,2,0,-1,0');
    });

    test('prefers a supplied country code over coordinate fallback', () {
      final profile = PrayerCalculationProfile.forLocation(
        latitude: 31.42,
        longitude: 34.38,
        countryCode: 'SA',
      );

      expect(profile.method, 4);
      expect(profile.tune, isNull);
    });

    test('uses the generic default outside known profiles', () {
      final profile = PrayerCalculationProfile.forLocation(
        latitude: 0,
        longitude: 0,
      );

      expect(profile.method, 3);
      expect(profile.school, 0);
      expect(profile.tune, isNull);
    });
  });
}
