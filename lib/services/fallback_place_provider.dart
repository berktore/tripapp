import '../core/app_exception.dart';
import '../core/log.dart';
import '../models/place.dart';
import 'place_provider.dart';

/// Birincil sağlayıcı başarısız olduğunda yedekleri sırayla dener.
///
/// Amaç: Overpass yoğun olduğunda veya yanıt vermediğinde planlamanın
/// tamamen durmaması. Dönen veri her durumda gerçek bir sağlayıcıdan
/// gelir; hiçbir aşamada mekân uydurulmaz.
class FallbackPlaceProvider implements PlaceProvider {
  FallbackPlaceProvider({
    required this.primary,
    this.fallbacks = const [],
  });

  final PlaceProvider primary;
  final List<PlaceProvider> fallbacks;

  @override
  Future<List<Place>> fetchPlaces({
    required double latitude,
    required double longitude,
  }) async {
    Object? primaryError;

    try {
      final places = await primary.fetchPlaces(
        latitude: latitude,
        longitude: longitude,
      );
      if (places.isNotEmpty) return places;
    } catch (error) {
      primaryError = error;
      logDebug('Birincil mekân sağlayıcısı başarısız', error: error);
    }

    for (final fallback in fallbacks) {
      try {
        final places = await fallback.fetchPlaces(
          latitude: latitude,
          longitude: longitude,
        );
        if (places.isNotEmpty) return places;
      } catch (error) {
        logDebug(
          '${fallback.runtimeType} yedek sağlayıcısı başarısız',
          error: error,
        );
      }
    }

    if (primaryError is AppException) throw primaryError;

    return const [];
  }
}
