import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/saved_imsakia_location.dart';

class SavedImsakiaLocationStore {
  static const _savedLocationsKey = 'savedImsakiaLocationsV1';
  static const _activeLocationKey = 'activeImsakiaLocationId';
  static const _tag = 'MUNIB_IMSAKIA';

  const SavedImsakiaLocationStore();

  Future<List<SavedImsakiaLocation>> load() async {
    debugPrint('[$_tag][STORE] LOAD start');
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_savedLocationsKey);
      if (savedJson == null || savedJson.isEmpty) {
        debugPrint('[$_tag][STORE] LOAD no saved locations');
        return <SavedImsakiaLocation>[];
      }

      final decoded = jsonDecode(savedJson);
      if (decoded is! List) {
        debugPrint('[$_tag][STORE][WARN] LOAD invalid root type=${decoded.runtimeType}');
        return <SavedImsakiaLocation>[];
      }
      final locations = decoded
          .whereType<Map>()
          .map((e) => SavedImsakiaLocation.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.prayers.isNotEmpty)
          .toList();
      debugPrint('[$_tag][STORE] LOAD success locations=${locations.length}');
      return locations;
    } catch (error, stackTrace) {
      debugPrint('[$_tag][STORE][EXCEPTION] LOAD failed: $error');
      debugPrint('[$_tag][STORE][STACK] $stackTrace');
      return <SavedImsakiaLocation>[];
    }
  }

  Future<void> save({
    required List<SavedImsakiaLocation> locations,
    required String? activeLocationId,
  }) async {
    debugPrint('[$_tag][STORE] SAVE start locations=${locations.length} active=$activeLocationId');
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(locations.map((e) => e.toJson()).toList());
      final saved = await prefs.setString(_savedLocationsKey, payload);
      debugPrint('[$_tag][STORE] SAVE locationsResult=$saved payloadBytes=${payload.length}');
      await _writeActiveLocation(prefs, activeLocationId);
      debugPrint('[$_tag][STORE] SAVE success');
    } catch (error, stackTrace) {
      debugPrint('[$_tag][STORE][EXCEPTION] SAVE failed: $error');
      debugPrint('[$_tag][STORE][STACK] $stackTrace');
      rethrow;
    }
  }

  Future<void> setActiveLocationId(String? activeLocationId) async {
    debugPrint('[$_tag][STORE] setActiveLocationId=$activeLocationId');
    try {
      final prefs = await SharedPreferences.getInstance();
      await _writeActiveLocation(prefs, activeLocationId);
    } catch (error, stackTrace) {
      debugPrint('[$_tag][STORE][EXCEPTION] setActiveLocationId failed: $error');
      debugPrint('[$_tag][STORE][STACK] $stackTrace');
      rethrow;
    }
  }

  Future<void> _writeActiveLocation(
    SharedPreferences prefs,
    String? activeLocationId,
  ) async {
    if (activeLocationId == null) {
      final removed = await prefs.remove(_activeLocationKey);
      debugPrint('[$_tag][STORE] activeLocation removed=$removed');
      return;
    }
    final saved = await prefs.setString(_activeLocationKey, activeLocationId);
    debugPrint('[$_tag][STORE] activeLocation saved=$saved id=$activeLocationId');
  }
}
