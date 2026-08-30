import 'prayer_day.dart';

class SavedImsakiaLocation {
  final String id;
  final String name;
  final String country;
  final double latitude;
  final double longitude;
  final String timezone;
  final List<PrayerDay> prayers;

  const SavedImsakiaLocation({
    required this.id,
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.prayers,
  });

  String get label => country.trim().isEmpty ? name : '$name, $country';

  SavedImsakiaLocation copyWith({List<PrayerDay>? prayers}) {
    return SavedImsakiaLocation(
      id: id,
      name: name,
      country: country,
      latitude: latitude,
      longitude: longitude,
      timezone: timezone,
      prayers: prayers ?? this.prayers,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'country': country,
        'latitude': latitude,
        'longitude': longitude,
        'timezone': timezone,
        'prayers': prayers.map((e) => e.toJson()).toList(),
      };

  factory SavedImsakiaLocation.fromJson(Map<String, dynamic> json) {
    final rawPrayers = json['prayers'] is List ? json['prayers'] as List : const [];
    return SavedImsakiaLocation(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      country: (json['country'] ?? '').toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      timezone: (json['timezone'] ?? '').toString(),
      prayers: rawPrayers
          .whereType<Map>()
          .map((e) => PrayerDay.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
