import 'dart:convert';

import 'package:http/http.dart' as http;

class MunibPlaceSearchResult {
  final String displayName;
  final String city;
  final String country;
  final String countryCode;
  final double latitude;
  final double longitude;

  const MunibPlaceSearchResult({
    required this.displayName,
    required this.city,
    required this.country,
    this.countryCode = '',
    required this.latitude,
    required this.longitude,
  });
}

class PlaceSearchService {
  Future<List<MunibPlaceSearchResult>> search(String query) async {
    final value = query.trim();
    if (value.length < 2) return const [];

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': value,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '12',
      'accept-language': 'ar,en',
    });

    final response = await http.get(
      uri,
      headers: const {
        'User-Agent': 'MunibPrayerApp/1.0 (global imsakia location search)',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('place_search_failed_${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];

    final seenCoordinates = <String>{};
    final seenPlaces = <String>{};
    final results = <MunibPlaceSearchResult>[];
    for (final raw in decoded) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final lat = double.tryParse((map['lat'] ?? '').toString());
      final lon = double.tryParse((map['lon'] ?? '').toString());
      if (lat == null || lon == null) continue;

      final address = map['address'] is Map
          ? Map<String, dynamic>.from(map['address'] as Map)
          : <String, dynamic>{};
      String firstNonEmpty(List<String> keys) {
        for (final key in keys) {
          final text = (address[key] ?? '').toString().trim();
          if (text.isNotEmpty) return text;
        }
        return '';
      }

      final city = firstNonEmpty([
        'city',
        'town',
        'village',
        'municipality',
        'county',
        'state_district',
        'state',
      ]);
      final region = firstNonEmpty([
        'state_district',
        'state',
        'county',
      ]);
      final country = (address['country'] ?? '').toString().trim();
      final countryCode =
          (address['country_code'] ?? '').toString().trim().toUpperCase();
      final display = (map['display_name'] ?? '').toString().trim();
      final label = [city, country].where((e) => e.isNotEmpty).join(', ');

      final coordinateKey =
          '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
      if (!seenCoordinates.add(coordinateKey)) continue;

      final placeKey = [city, region, countryCode.isNotEmpty ? countryCode : country]
          .map((part) => part.trim().toLowerCase())
          .where((part) => part.isNotEmpty)
          .join('|');
      if (placeKey.isNotEmpty && !seenPlaces.add(placeKey)) continue;

      results.add(MunibPlaceSearchResult(
        displayName: display.isNotEmpty ? display : label,
        city: city.isNotEmpty ? city : (label.isNotEmpty ? label : value),
        country: country,
        countryCode: countryCode,
        latitude: lat,
        longitude: lon,
      ));
    }
    return results;
  }
}
