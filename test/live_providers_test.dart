import 'package:flutter_test/flutter_test.dart';
import 'package:tripapp/models/destination_ref.dart';
import 'package:tripapp/services/destination_places_service.dart';
import 'package:tripapp/services/fallback_place_provider.dart';
import 'package:tripapp/services/nominatim_service.dart';
import 'package:tripapp/services/overpass_place_provider.dart';
import 'package:tripapp/services/weather_service.dart';
import 'package:tripapp/services/wikipedia_place_provider.dart';

/// Canlı sağlayıcı kontrolü. Varsayılan olarak atlanır:
/// `flutter test test/live_providers_test.dart --dart-define=LIVE=true`
void main() {
  const live = bool.fromEnvironment('LIVE');

  test('Nominatim Kyoto için gerçek koordinat döndürür', () async {
    final resolved = await NominatimService().resolve(
      const DestinationRef(name: 'Kyoto', countryCode: 'jp'),
    );

    // ignore: avoid_print
    print('Kyoto -> ${resolved.latitude}, ${resolved.longitude}');

    expect(resolved.hasCoordinates, isTrue);
    expect(resolved.latitude!, closeTo(35.0, 1.0));
    expect(resolved.longitude!, closeTo(135.8, 1.5));
  }, skip: !live);

  test(
    'Overpass Kyoto çevresinde gerçek mekân döndürür',
    () async {
      final places = await OverpassPlaceProvider().fetchPlaces(
        latitude: 35.0116,
        longitude: 135.7681,
      );

      // ignore: avoid_print
      print('Overpass: ${places.length} mekân');
      for (final place in places.take(8)) {
        // ignore: avoid_print
        print(
          '- ${place.name} [${place.category}] '
          '${place.latitude},${place.longitude}',
        );
      }

      expect(places, isNotEmpty);
      expect(places.every((place) => place.name.isNotEmpty), isTrue);
      expect(
        places.every(
          (place) => place.latitude.abs() <= 90 && place.longitude.abs() <= 180,
        ),
        isTrue,
      );
      expect(places.every((place) => place.osmId.contains('/')), isTrue);
    },
    skip: !live,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'Wikipedia İstanbul çevresinde gerçek mekân döndürür',
    () async {
      final places = await WikipediaPlaceProvider().fetchPlaces(
        latitude: 41.0082,
        longitude: 28.9784,
      );

      // ignore: avoid_print
      print('Wikipedia: ${places.length} mekân');
      for (final place in places.take(8)) {
        // ignore: avoid_print
        print(
          '- ${place.name} [${place.category}] ${place.latitude},'
          '${place.longitude} ${place.sourceUrl}',
        );
      }

      expect(places, isNotEmpty);
      expect(places.every((place) => place.source == 'Wikipedia'), isTrue);
      expect(places.every((place) => place.description.isNotEmpty), isTrue);
      expect(
        places.every(
          (place) => place.latitude.abs() <= 90 && place.longitude.abs() <= 180,
        ),
        isTrue,
      );
    },
    skip: !live,
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    'Wikipedia verisiyle uçtan uca plan üretilir',
    () async {
      final itinerary =
          await DestinationPlacesService(
            provider: FallbackPlaceProvider(primary: WikipediaPlaceProvider()),
          ).buildItinerary(
            destination: const DestinationRef(
              name: 'İstanbul',
              countryCode: 'tr',
            ),
            dayCount: 2,
            styles: const ['Kültür'],
            startDate: DateTime.now().add(const Duration(days: 1)),
          );

      for (final day in itinerary) {
        // ignore: avoid_print
        print('${day.dayNumber}. Gün (${day.stops.length} durak)');
        for (final stop in day.stops) {
          // ignore: avoid_print
          print('  ${stop.time} ${stop.title} [${stop.category}]');
        }
      }

      expect(itinerary, hasLength(2));
      expect(itinerary.expand((day) => day.stops), isNotEmpty);
    },
    skip: !live,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('Open-Meteo gerçek tahmin döndürür', () async {
    final result = await WeatherService().getForecast(
      latitude: 35.0116,
      longitude: 135.7681,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 2)),
    );

    // ignore: avoid_print
    print(
      'Hava: ${result.days.map((d) => '${d.date.day}.${d.date.month} '
          '${d.minTemperature}-${d.maxTemperature}').join(' | ')}',
    );

    expect(result.hasData, isTrue);
  }, skip: !live);

  test(
    'Uçtan uca plan gerçek veriyle üretilir',
    () async {
      final itinerary = await DestinationPlacesService().buildItinerary(
        destination: const DestinationRef(name: 'Kyoto', countryCode: 'jp'),
        dayCount: 2,
        styles: const ['Kültür'],
        startDate: DateTime.now().add(const Duration(days: 1)),
      );

      for (final day in itinerary) {
        // ignore: avoid_print
        print('${day.dayNumber}. Gün (${day.stops.length} durak)');
        for (final stop in day.stops) {
          // ignore: avoid_print
          print(
            '  ${stop.time} ${stop.title} [${stop.category}] '
            '${stop.latitude},${stop.longitude}',
          );
        }
      }

      expect(itinerary, hasLength(2));
      expect(itinerary.expand((day) => day.stops), isNotEmpty);
      expect(
        itinerary
            .expand((day) => day.stops)
            .every((stop) => stop.hasCoordinates && stop.osmId != null),
        isTrue,
      );
    },
    skip: !live,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
