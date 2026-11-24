import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_exception.dart';
import '../core/log.dart';
import '../models/trip_plan.dart';

class TripLoadResult {
  const TripLoadResult({required this.trips, this.skipped = 0});

  final List<TripPlan> trips;
  final int skipped;
}

class TripStorage {
  static const String _storageKey = 'tripapp_saved_trips';

  /// Her kaydı ayrı ayrı çözer. Bozuk bir kayıt diğerlerini silmez;
  /// kaç kaydın okunamadığı [TripLoadResult.skipped] ile bildirilir.
  static Future<TripLoadResult> loadTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);

    if (data == null || data.isEmpty) {
      return const TripLoadResult(trips: []);
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(data);
    } catch (error) {
      logDebug('Kayıtlı geziler çözümlenemedi', error: error);
      return const TripLoadResult(trips: [], skipped: 1);
    }

    if (decoded is! List) {
      return const TripLoadResult(trips: [], skipped: 1);
    }

    final trips = <TripPlan>[];
    var skipped = 0;

    for (final item in decoded) {
      try {
        trips.add(
          TripPlan.fromJson(Map<String, dynamic>.from(item as Map)),
        );
      } catch (error) {
        skipped++;
        logDebug('Bir gezi kaydı okunamadı', error: error);
      }
    }

    return TripLoadResult(trips: trips, skipped: skipped);
  }

  static Future<List<TripPlan>> getTrips() async {
    final result = await loadTrips();
    return List<TripPlan>.of(result.trips);
  }

  static Future<void> _writeTrips(List<TripPlan> trips) async {
    final prefs = await SharedPreferences.getInstance();

    final success = await prefs.setString(
      _storageKey,
      jsonEncode(trips.map((trip) => trip.toJson()).toList()),
    );

    if (!success) {
      throw const AppException(
        'Gezi planı cihaz hafızasına kaydedilemedi.',
        kind: AppErrorKind.storage,
      );
    }
  }

  static Future<void> saveTrip(TripPlan trip) async {
    final trips = await getTrips();

    trips.removeWhere((item) => item.id == trip.id);
    trips.insert(0, trip);

    await _writeTrips(trips);
  }

  /// [destination] ile eşleşen ilk kayıtlı gezinin ilk gününe mekân ekler.
  /// Aynı mekân zaten ekliyse veya eşleşen gezi yoksa `false` döner.
  static Future<bool> addStopToDestination({
    required String destination,
    required ItineraryStop stop,
  }) async {
    final trips = await getTrips();
    final normalizedDestination = _normalize(destination);

    final tripIndex = trips.indexWhere(
      (trip) => _normalize(trip.destination) == normalizedDestination,
    );

    if (tripIndex == -1) return false;

    final trip = trips[tripIndex];
    final days = List<ItineraryDay>.from(trip.itinerary);

    final alreadyExists = days.any(
      (day) => day.stops.any((existing) => _isSameStop(existing, stop)),
    );

    if (alreadyExists) return false;

    if (days.isEmpty) {
      days.add(
        ItineraryDay(
          dayNumber: 1,
          title: '${trip.destination} keşif rotası',
          stops: [stop],
        ),
      );
    } else {
      final firstDay = days.first;

      days[0] = firstDay.copyWith(stops: [...firstDay.stops, stop]);
    }

    trips[tripIndex] = trip.copyWith(itinerary: days);

    await _writeTrips(trips);
    return true;
  }

  /// Favori durumunu değiştirir ve yeni değeri döndürür.
  /// Gezi bulunamazsa `null` döner.
  static Future<bool?> toggleFavorite(String tripId) async {
    final trips = await getTrips();
    final index = trips.indexWhere((trip) => trip.id == tripId);

    if (index == -1) return null;

    final updated = trips[index].copyWith(
      isFavorite: !trips[index].isFavorite,
    );
    trips[index] = updated;

    await _writeTrips(trips);
    return updated.isFavorite;
  }

  /// Belirtilen günden bir durağı kaldırır.
  static Future<bool> removeStop({
    required String tripId,
    required int dayNumber,
    required String title,
    String? osmId,
  }) async {
    final trips = await getTrips();
    final index = trips.indexWhere((trip) => trip.id == tripId);
    if (index == -1) return false;

    final trip = trips[index];
    var removed = false;

    final itinerary = trip.itinerary.map((day) {
      if (day.dayNumber != dayNumber) return day;

      final stops = day.stops.where((stop) {
        final matches = _sameStopData(stop, title, osmId);
        if (matches) removed = true;
        return !matches;
      }).toList();

      return day.copyWith(stops: stops);
    }).toList();

    if (!removed) return false;

    trips[index] = trip.copyWith(itinerary: itinerary);
    await _writeTrips(trips);
    return true;
  }

  static bool _isSameStop(ItineraryStop a, ItineraryStop b) {
    if (a.osmId != null && b.osmId != null && a.osmId == b.osmId) {
      return true;
    }
    return _normalize(a.title) == _normalize(b.title);
  }

  static bool _sameStopData(
    ItineraryStop stop,
    String title,
    String? osmId,
  ) {
    if (osmId != null && stop.osmId != null && stop.osmId == osmId) {
      return true;
    }
    return _normalize(stop.title) == _normalize(title);
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i');
  }

  static Future<void> deleteTrip(String id) async {
    final trips = await getTrips();

    trips.removeWhere((trip) => trip.id == id);

    await _writeTrips(trips);
  }
}
