import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/saved_imsakia_location.dart';

class SavedImsakiaLocationStore {
  static const _savedLocationsKey = 'savedImsakiaLocationsV1';
  static const _activeLocationKey = 'activeImsakiaLocationId';

  const SavedImsakiaLocationStore();

  Future<List<SavedImsakiaLocation>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString(_savedLocationsKey);
    if (savedJson == null || savedJson.isEmpty) return const [];

    try {
      final decoded = jsonDecode(savedJson);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => SavedImsakiaLocation.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.prayers.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save({
    required List<SavedImsakiaLocation> locations,
    required String? activeLocationId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedLocationsKey,
      jsonEncode(locations.map((e) => e.toJson()).toList()),
    );
    await _writeActiveLocation(prefs, activeLocationId);
  }

  Future<void> setActiveLocationId(String? activeLocationId) async {
    final prefs = await SharedPreferences.getInstance();
    await _writeActiveLocation(prefs, activeLocationId);
  }

  Future<void> _writeActiveLocation(
    SharedPreferences prefs,
    String? activeLocationId,
  ) async {
    if (activeLocationId == null) {
      await prefs.remove(_activeLocationKey);
      return;
    }
    await prefs.setString(_activeLocationKey, activeLocationId);
  }
}
