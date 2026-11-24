import '../models/place.dart';

/// Gerçek mekân verisi sağlayan katmanın sözleşmesi.
///
/// Bugün iki uygulama var:
/// - [OverpassPlaceProvider] (OpenStreetMap, birincil)
/// - [WikipediaPlaceProvider] (Wikipedia GeoSearch, yedek)
abstract class PlaceProvider {
  Future<List<Place>> fetchPlaces({
    required double latitude,
    required double longitude,
  });
}
