import 'package:flutter_test/flutter_test.dart';
import 'package:tripapp/services/place_filter_service.dart';

class _FakePlace {
  const _FakePlace({
    required this.name,
    required this.id,
    required this.latitude,
    required this.longitude,
    this.category = 'Müze',
  });

  final String name;
  final String id;
  final double? latitude;
  final double? longitude;
  final String category;
}

void main() {
  const service = PlaceFilterService();

  List<_FakePlace> filter(List<_FakePlace> places) {
    return service.filter<_FakePlace>(
      places: places,
      getName: (place) => place.name,
      getId: (place) => place.id,
      getLatitude: (place) => place.latitude,
      getLongitude: (place) => place.longitude,
      getCategory: (place) => place.category,
    );
  }

  test('aynı OSM kimliğine sahip mekânları tekilleştirir', () {
    final result = filter(const [
      _FakePlace(name: 'Ayasofya', id: 'way/1', latitude: 41.0, longitude: 29.0),
      _FakePlace(name: 'Ayasofya', id: 'way/1', latitude: 41.0, longitude: 29.0),
    ]);

    expect(result, hasLength(1));
  });

  test('kimlik yoksa isim ve koordinatla tekilleştirir', () {
    final result = filter(const [
      _FakePlace(name: 'Anıtkabir', id: '', latitude: 39.925, longitude: 32.836),
      _FakePlace(name: 'anıtkabir', id: '', latitude: 39.9250, longitude: 32.8360),
      _FakePlace(name: 'Anıtkabir', id: '', latitude: 41.0, longitude: 29.0),
    ]);

    expect(result, hasLength(2));
  });

  test('geçersiz veya eksik koordinatları ayıklar', () {
    final result = filter(const [
      _FakePlace(name: 'Geçerli', id: '1', latitude: 39.0, longitude: 35.0),
      _FakePlace(name: 'Boş', id: '2', latitude: null, longitude: 35.0),
      _FakePlace(name: 'Sınır dışı', id: '3', latitude: 120.0, longitude: 35.0),
      _FakePlace(name: 'NaN', id: '4', latitude: double.nan, longitude: 35.0),
    ]);

    expect(result, hasLength(1));
    expect(result.single.name, 'Geçerli');
  });

  test('boş isim veya kategori taşıyan kayıtları atar', () {
    final result = filter(const [
      _FakePlace(name: '', id: '1', latitude: 39.0, longitude: 35.0),
      _FakePlace(
        name: 'Kategorisiz',
        id: '2',
        latitude: 39.0,
        longitude: 35.0,
        category: '',
      ),
    ]);

    expect(result, isEmpty);
  });

  test('mesafe hesabı İstanbul-Ankara için ~350 km verir', () {
    final distance = service.distanceKm(
      latitude1: 41.0082,
      longitude1: 28.9784,
      latitude2: 39.9334,
      longitude2: 32.8597,
    );

    expect(distance, greaterThan(330));
    expect(distance, lessThan(370));
  });
}
