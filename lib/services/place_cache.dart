import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/log.dart';
import '../models/place.dart';

/// Sağlayıcı yanıtlarını cihazda tutan küçük, TTL'li önbellek.
///
/// Neden SharedPreferences? Proje hem Android hem web hedefliyor ve sıfır
/// bütçede ek veritabanı bağımlılığı eklemek istemiyoruz. Veri hacmi
/// (bir şehir için birkaç yüz mekân) bu katman için yeterince küçük.
/// Faz 4'te SQLite/Drift'e taşınması önerilir.
class PlaceCache {
  static const String _storageKey = 'tripapp_place_cache_v2';
  static const Duration _ttl = Duration(hours: 72);
  static const int _maxEntries = 8;

  Future<List<Place>?> read({
    required double latitude,
    required double longitude,
    bool allowStale = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final entry = decoded[_keyFor(latitude, longitude)];
      if (entry is! Map) return null;

      final timestamp = entry['timestamp'];
      final rawPlaces = entry['places'];
      if (timestamp is! int || rawPlaces is! List) return null;

      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(timestamp),
      );
      if (!allowStale && age > _ttl) return null;

      return rawPlaces
          .whereType<Map>()
          .map((item) => Place.fromJson(Map<String, dynamic>.from(item)))
          .where((place) => place.name.isNotEmpty)
          .toList();
    } catch (error) {
      logDebug('Mekân önbelleği okunamadı', error: error);
      return null;
    }
  }

  Future<void> write({
    required double latitude,
    required double longitude,
    required List<Place> places,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final decoded = <String, dynamic>{};

      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final parsed = jsonDecode(raw);
        if (parsed is Map) {
          decoded.addAll(Map<String, dynamic>.from(parsed));
        }
      }

      decoded[_keyFor(latitude, longitude)] = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'places': places.map((place) => place.toJson()).toList(),
      };

      _prune(decoded);
      await prefs.setString(_storageKey, jsonEncode(decoded));
    } catch (error) {
      // Önbellek yalnızca hızlandırma katmanıdır; yazılamazsa akış bozulmaz.
      logDebug('Mekân önbelleği yazılamadı', error: error);
    }
  }

  /// Profil ekranındaki "önbelleği temizle" işlemi için.
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (error) {
      logDebug('Mekân önbelleği temizlenemedi', error: error);
    }
  }

  void _prune(Map<String, dynamic> entries) {
    if (entries.length <= _maxEntries) return;

    final sorted = entries.entries.toList()
      ..sort((a, b) {
        final aTime = _timestampOf(a.value);
        final bTime = _timestampOf(b.value);
        return aTime.compareTo(bTime);
      });

    while (entries.length > _maxEntries && sorted.isNotEmpty) {
      final oldest = sorted.removeAt(0);
      entries.remove(oldest.key);
    }
  }

  int _timestampOf(Object? value) {
    if (value is Map && value['timestamp'] is int) {
      return value['timestamp'] as int;
    }
    return 0;
  }

  String _keyFor(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(3)}:${longitude.toStringAsFixed(3)}';
}
