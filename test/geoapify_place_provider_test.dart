import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tripapp/services/geoapify_place_provider.dart';

void main() {
  test('Geoapify bar ve alışveriş sonuçlarını doğru sınıflandırır', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'api.geoapify.com');
      expect(request.url.queryParameters['apiKey'], 'test-key');
      return http.Response(
        jsonEncode({
          'features': [
            {
              'properties': {
                'place_id': 'bar-1',
                'name': 'Gece Barı',
                'categories': ['catering.bar'],
                'formatted': 'Kyoto, Japonya',
              },
              'geometry': {
                'type': 'Point',
                'coordinates': [135.76, 35.01],
              },
            },
            {
              'properties': {
                'place_id': 'shop-1',
                'name': 'Alışveriş Sokağı',
                'categories': ['commercial.clothing'],
              },
              'geometry': {
                'type': 'Point',
                'coordinates': [135.77, 35.02],
              },
            },
          ],
        }),
        200,
 headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final places = await GeoapifyPlaceProvider(
      client: client,
      apiKey: 'test-key',
    ).fetchPlaces(latitude: 35.01, longitude: 135.76);

    expect(places.map((place) => place.category), [
      'Gece Hayatı',
      'Alışveriş',
    ]);
    expect(places.first.osmId, 'geoapify:bar-1');
  });
}
