import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripapp/models/trip_plan.dart';
import 'package:tripapp/services/trip_storage.dart';

TripPlan _buildTrip({String id = 'trip-1', String destination = 'Kyoto'}) {
  return TripPlan(
    id: id,
    destination: destination,
    startDate: DateTime(2026, 4, 10),
    endDate: DateTime(2026, 4, 12),
    travelers: '2 kişi',
    budget: 'Orta',
    travelStyles: const ['Kültür'],
    createdAt: DateTime(2026, 3, 1),
    latitude: 35.0116,
    longitude: 135.7681,
    itinerary: const [
      ItineraryDay(
        dayNumber: 1,
        title: 'Kyoto · 1. Gün',
        stops: [
          ItineraryStop(
            time: '09:00',
            title: 'Kiyomizu-dera',
            description: 'Tarihî tapınak.',
            category: 'Budist Tapınağı',
            latitude: 34.9949,
            longitude: 135.785,
            osmId: 'node/1',
          ),
        ],
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('TripPlan JSON gidiş-dönüşünde veriyi korur', () {
    final trip = _buildTrip();
    final restored = TripPlan.fromJson(
      Map<String, dynamic>.from(jsonDecode(jsonEncode(trip.toJson())) as Map),
    );

    expect(restored.id, trip.id);
    expect(restored.destination, trip.destination);
    expect(restored.latitude, trip.latitude);
    expect(restored.longitude, trip.longitude);
    expect(restored.isFavorite, isFalse);
    expect(restored.duration, 3);
    expect(restored.itinerary.single.stops.single.osmId, 'node/1');
    expect(restored.dateForDay(2), DateTime(2026, 4, 11));
  });

  test('gezi kaydedilir ve geri okunur', () async {
    final trip = _buildTrip();

    await TripStorage.saveTrip(trip);

    final result = await TripStorage.loadTrips();

    expect(result.skipped, 0);
    expect(result.trips, hasLength(1));
    expect(result.trips.single.destination, 'Kyoto');
  });

  test('aynı kimlikle kaydetmek kaydı çoğaltmaz', () async {
    await TripStorage.saveTrip(_buildTrip());
    await TripStorage.saveTrip(_buildTrip(destination: 'Kyoto'));

    final result = await TripStorage.loadTrips();

    expect(result.trips, hasLength(1));
  });

  test('bozuk kayıt diğer gezileri silmez', () async {
    final valid = _buildTrip();
    SharedPreferences.setMockInitialValues({
      'tripapp_saved_trips': jsonEncode([valid.toJson(), 'bozuk kayıt']),
    });

    final result = await TripStorage.loadTrips();

    expect(result.trips, hasLength(1));
    expect(result.skipped, 1);
  });

  test('tamamen bozuk JSON boş sonuç ve uyarı döndürür', () async {
    SharedPreferences.setMockInitialValues({
      'tripapp_saved_trips': '{"bozuk": ',
    });

    final result = await TripStorage.loadTrips();

    expect(result.trips, isEmpty);
    expect(result.skipped, 1);
  });

  test('durak kaldırma yalnızca eşleşen günü değiştirir', () async {
    final trip = _buildTrip();
    await TripStorage.saveTrip(trip);

    final removed = await TripStorage.removeStop(
      tripId: trip.id,
      dayNumber: 1,
      title: 'Kiyomizu-dera',
      osmId: 'node/1',
    );

    final result = await TripStorage.loadTrips();

    expect(removed, isTrue);
    expect(result.trips.single.itinerary.single.stops, isEmpty);
  });

  test('var olmayan durak kaldırılamaz', () async {
    final trip = _buildTrip();
    await TripStorage.saveTrip(trip);

    final removed = await TripStorage.removeStop(
      tripId: trip.id,
      dayNumber: 1,
      title: 'Olmayan Durak',
    );

    expect(removed, isFalse);
  });

  test('favori durumu değiştirilir ve kalıcı olur', () async {
    await TripStorage.saveTrip(_buildTrip());

    expect(await TripStorage.toggleFavorite('trip-1'), isTrue);

    final favorited = await TripStorage.loadTrips();
    expect(favorited.trips.single.isFavorite, isTrue);

    expect(await TripStorage.toggleFavorite('trip-1'), isFalse);
    expect(await TripStorage.toggleFavorite('olmayan'), isNull);
  });

  test('gezi silinir', () async {    final trip = _buildTrip();
    await TripStorage.saveTrip(trip);

    await TripStorage.deleteTrip(trip.id);

    final result = await TripStorage.loadTrips();
    expect(result.trips, isEmpty);
  });
}
