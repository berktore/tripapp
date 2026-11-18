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
            (item) => TripPlan.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _writeTrips(List<TripPlan> trips) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(trips.map((trip) => trip.toJson()).toList()),
    );
  }

  static Future<void> saveTrip(TripPlan trip) async {
    final trips = await getTrips();
    trips.removeWhere((item) => item.id == trip.id);
    trips.insert(0, trip);
    await _writeTrips(trips);
  }

  /// Adds a map place to the first saved trip matching [destination].
  /// Returns false when the user has not created a matching trip yet.
  /// Returns true when added, false when already present or no trip exists.
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

    for (final day in days) {
      if (day.stops.any(
        (existing) => _normalize(existing.title) == _normalize(stop.title),
      )) {
        return false;
      }
    }

    if (days.isEmpty) {
      days.add(
        ItineraryDay(
          dayNumber: 1,
          title: 'Antalya keşif rotası',
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

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll('ı', 'i');

  static Future<void> deleteTrip(String id) async {
    final trips = await getTrips();
    trips.removeWhere((trip) => trip.id == id);
    await _writeTrips(trips);
  }
}
