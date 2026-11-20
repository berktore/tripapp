
import 'dart:math' as math;

/// Gezi planına girmeden önce mekânları temizler.
/// OSM kimliği, koordinat ve isim üzerinden mükerrer kayıtları ayıklar.
class PlaceFilterService {
  const PlaceFilterService();

  List<T> filter<T>({
    required List<T> places,
    required String Function(T place) getName,
    required String Function(T place) getId,
    required double? Function(T place) getLatitude,
    required double? Function(T place) getLongitude,
    required String Function(T place) getCategory,
  }) {
    final uniquePlaces = <String, T>{};

    for (final place in places) {
      final name = getName(place).trim();
      final id = getId(place).trim();
      final latitude = getLatitude(place);
      final longitude = getLongitude(place);
      final category = getCategory(place).trim();

      if (name.isEmpty || category.isEmpty) continue;

      if (latitude == null || longitude == null) continue;

      if (!_isValidCoordinate(latitude, longitude)) continue;

      final normalizedName = _normalize(name);

      // Öncelik OSM kimliğinde. Kimlik yoksa isim ve koordinat kullanılır.
      final key = id.isNotEmpty
          ? 'osm:$id'
          : 'place:$normalizedName:${latitude.toStringAsFixed(4)}:${longitude.toStringAsFixed(4)}';

      uniquePlaces.putIfAbsent(key, () => place);
    }

    return uniquePlaces.values.toList();
  }

  bool _isValidCoordinate(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// İki koordinat arasındaki kuş uçuşu mesafeyi kilometre olarak hesaplar.
  double distanceKm({
    required double latitude1,
    required double longitude1,
    required double latitude2,
    required double longitude2,
  }) {
    const earthRadius = 6371.0;

    double radians(double degrees) => degrees * math.pi / 180;

    final lat1 = radians(latitude1);
    final lat2 = radians(latitude2);
    final deltaLat = radians(latitude2 - latitude1);
    final deltaLon = radians(longitude2 - longitude1);

    final value =
        math.pow(math.sin(deltaLat / 2), 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.pow(math.sin(deltaLon / 2), 2);

    final safeValue = value.clamp(0.0, 1.0);

    return earthRadius *
        2 *
        math.atan2(math.sqrt(safeValue), math.sqrt(1 - safeValue));
  }
}
