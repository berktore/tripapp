import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripapp/models/trip_plan.dart';
import 'package:tripapp/screens/plans_screen.dart';
import 'package:tripapp/services/trip_storage.dart';

TripPlan _trip() => TripPlan(
  id: 'trip-1',
  destination: 'Kyoto',
  startDate: DateTime(2026, 4, 10),
  endDate: DateTime(2026, 4, 12),
  travelers: '2 kişi',
  budget: 'Orta',
  travelStyles: const ['Kültür'],
  createdAt: DateTime(2026, 3, 1),
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
          source: 'OpenStreetMap',
          sourceUrl: 'https://www.openstreetmap.org/node/1',
        ),
      ],
    ),
  ],
);

Future<void> _pumpPlans(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: PlansScreen()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('kayıtlı plan listede görünür', (tester) async {
    await TripStorage.saveTrip(_trip());

    await _pumpPlans(tester);

    expect(find.text('Kyoto'), findsOneWidget);
    expect(find.text('3 günlük yolculuk'), findsOneWidget);
  });

  testWidgets('favori ekleme kalıcı olur ve filtre çalışır', (tester) async {
    await TripStorage.saveTrip(_trip());

    await _pumpPlans(tester);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    final stored = await TripStorage.loadTrips();
    expect(stored.trips.single.isFavorite, isTrue);

    await tester.tap(find.text('Favoriler (1)'));
    await tester.pump();

    expect(find.text('Kyoto'), findsOneWidget);
  });

  testWidgets('favori yokken filtre boş durumu gösterir', (tester) async {
    await TripStorage.saveTrip(_trip());

    await _pumpPlans(tester);

    await tester.tap(find.text('Favoriler (0)'));
    await tester.pump();

    expect(find.text('Henüz favori gezin yok.'), findsOneWidget);
  });
}
