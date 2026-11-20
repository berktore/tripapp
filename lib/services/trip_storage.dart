
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/trip_plan.dart';

class TripStorage {
  static const String _storageKey = 'tripapp_saved_trips';

  static Future<List<TripPlan>> getTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);

    if (data == null || data.isEmpty) return [];

    try {
      final decoded = jsonDecode(data) as List<dynamic>;
      return decoded
          .map(
            (item) => TripPlan.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _writeTrips(List<TripPlan> trips) async {
    final prefs = await SharedPreferences.getInstance();

    final success = await prefs.setString(
      _storageKey,
      jsonEncode(trips.map((trip) => trip.toJson()).toList()),
    );

    if (!success) {
      throw Exception('Gezi planı cihaz hafızasına kaydedilemedi.');
    }
  }

  static Future<void> saveTrip(TripPlan trip) async {
    final trips = await getTrips();

    trips.removeWhere((item) => item.id == trip.id);
    trips.insert(0, trip);

    await _writeTrips(trips);
  }

  /// Adds a place to the first saved trip matching [destination].
  /// Returns false if no matching trip exists or the place is already saved.
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
      (day) => day.stops.any(
        (existing) =>
            existing.osmId != null &&
            stop.osmId != null &&
            existing.osmId == stop.osmId ||
            _normalize(existing.title) == _normalize(stop.title),
      ),
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

      days[0] = ItineraryDay(
        dayNumber: firstDay.dayNumber,
        title: firstDay.title,
        stops: [...firstDay.stops, stop],
      );
    }

    trips[tripIndex] = TripPlan(
      id: trip.id,
      destination: trip.destination,
      imageUrl: trip.imageUrl,
      startDate: trip.startDate,
      endDate: trip.endDate,
      travelers: trip.travelers,
      budget: trip.budget,
      travelStyles: trip.travelStyles,
      createdAt: trip.createdAt,
      itinerary: days,
    );

    await _writeTrips(trips);
    return true;
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
