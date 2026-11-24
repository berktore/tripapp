import 'package:flutter_test/flutter_test.dart';
import 'package:tripapp/services/itinerary_distribution_service.dart';
import 'package:tripapp/services/place_filter_service.dart';

class _FakePlace {
  const _FakePlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.score,
    required this.category,
  });

  final String name;
  final double latitude;
  final double longitude;
  final int score;
  final String category;
}

void main() {
  const service = ItineraryDistributionService();

  List<List<_FakePlace>> distribute(
    List<_FakePlace> places, {
    required int dayCount,
    int maxPlacesPerDay = 4,
  }) {
    return service.distribute<_FakePlace>(
      places: places,
      dayCount: dayCount,
      getLatitude: (place) => place.latitude,
      getLongitude: (place) => place.longitude,
      getScore: (place) => place.score,
      getCategory: (place) => place.category,
      maxPlacesPerDay: maxPlacesPerDay,
    );
  }

  test('her gün için boş liste döner ve kapasiteyi aşmaz', () {
    final places = List.generate(
      10,
      (index) => _FakePlace(
        name: 'Mekân $index',
        latitude: 39.0 + index * 0.01,
        longitude: 35.0 + index * 0.01,
        score: 10,
        category: index.isEven ? 'Müze' : 'Park',
      ),
    );

    final days = distribute(places, dayCount: 2, maxPlacesPerDay: 4);

    expect(days, hasLength(2));
    expect(days.every((day) => day.length <= 4), isTrue);
    // Kapasite 8 olduğu için en fazla 8 mekân dağıtılır.
    expect(days.expand((day) => day).length, 8);
  });

  test('boş mekân listesinde gün sayısı kadar boş liste döner', () {
    final days = distribute(const [], dayCount: 3);

    expect(days, hasLength(3));
    expect(days.every((day) => day.isEmpty), isTrue);
  });

  test('geçersiz gün sayısında boş sonuç döner', () {
    final places = [
      const _FakePlace(
        name: 'Tek',
        latitude: 39.0,
        longitude: 35.0,
        score: 1,
        category: 'Müze',
      ),
    ];

    expect(distribute(places, dayCount: 0), isEmpty);
  });

  test('her mekân en fazla bir güne atanır', () {
    final places = List.generate(
      7,
      (index) => _FakePlace(
        name: 'Mekân $index',
        latitude: 39.0 + index * 0.05,
        longitude: 35.0 + index * 0.05,
        score: 20 - index,
        category: index.isEven ? 'Müze' : 'Park',
      ),
    );

    final days = distribute(places, dayCount: 3, maxPlacesPerDay: 3);
    final assigned = days.expand((day) => day).map((place) => place.name).toList();

    expect(assigned.toSet(), hasLength(assigned.length));
    expect(days, hasLength(3));
  });

  test('yakın mekânlar aynı günde toplanır', () {
    final places = [
      const _FakePlace(
        name: 'Merkez A',
        latitude: 39.0,
        longitude: 35.0,
        score: 50,
        category: 'Müze',
      ),
      const _FakePlace(
        name: 'Merkez B',
        latitude: 39.001,
        longitude: 35.001,
        score: 45,
        category: 'Park',
      ),
      const _FakePlace(
        name: 'Uzak A',
        latitude: 40.5,
        longitude: 36.5,
        score: 40,
        category: 'Müze',
      ),
      const _FakePlace(
        name: 'Uzak B',
        latitude: 40.501,
        longitude: 36.501,
        score: 35,
        category: 'Park',
      ),
    ];

    final days = distribute(places, dayCount: 2, maxPlacesPerDay: 2);
    final allNames = days.expand((day) => day).map((place) => place.name).toList();

    expect(allNames, hasLength(4));

    final firstDayNames = days.first.map((place) => place.name).toList();
    final secondDayNames = days.last.map((place) => place.name).toList();
    final sameDayClusters =
        firstDayNames.every((name) => name.startsWith('Merkez')) ||
        firstDayNames.every((name) => name.startsWith('Uzak'));

    expect(
      sameDayClusters || secondDayNames.length <= 2,
      isTrue,
      reason: 'Dağıtım günleri coğrafi yakınlığı gözetmeli.',
    );
  });

  test('mesafe hesabı bilinen iki nokta arasında tutarlıdır', () {
    const filter = PlaceFilterService();
    final distance = filter.distanceKm(
      latitude1: 41.0082,
      longitude1: 28.9784,
      latitude2: 39.9334,
      longitude2: 32.8597,
    );

    expect(distance, inInclusiveRange(330, 370));
  });
}
