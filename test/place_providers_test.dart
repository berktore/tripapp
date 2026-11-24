import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tripapp/core/app_exception.dart';
import 'package:tripapp/models/place.dart';
import 'package:tripapp/services/fallback_place_provider.dart';
import 'package:tripapp/services/place_provider.dart';
import 'package:tripapp/services/wikipedia_place_provider.dart';

const _center = (35.0116, 135.7681);

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _geoSearchPayload() => {
  'query': {
    'geosearch': [
      {'pageid': 101, 'title': 'Kiyomizu-dera', 'dist': 120.5},
      {'pageid': 102, 'title': 'Kyoto Imperial Palace', 'dist': 400.0},
      {'pageid': 103, 'title': 'Anlasmazlik sayfasi', 'dist': 500.0},
      {'pageid': 104, 'title': 'Koordinatsiz sayfa', 'dist': 600.0},
      {'pageid': 105, 'title': 'Köprülü Kütüphanesi', 'dist': 700.0},
    ],
  },
};

Map<String, dynamic> _detailsPayload() => {
  'query': {
    'pages': {
      '101': {
        'pageid': 101,
        'title': 'Kiyomizu-dera',
        'coordinates': [
          {'lat': 34.9949, 'lon': 135.7850},
        ],
        'extract':
            'Kiyomizu-dera is a historic Buddhist temple in Kyoto. '
            'It is a UNESCO World Heritage Site.',
        'fullurl': 'https://tr.wikipedia.org/wiki/Kiyomizu-dera',
      },
      '102': {
        'pageid': 102,
        'title': 'Kyoto Imperial Palace',
        'coordinates': [
          {'lat': 35.0254, 'lon': 135.7621},
        ],
        'extract': 'Kyoto Imparatorluk Sarayi, Kyoto merkezinde yer alir.',
        'fullurl': 'https://tr.wikipedia.org/wiki/Kyoto_Imperial_Palace',
      },
      '103': {
        'pageid': 103,
        'title': 'Anlasmazlik sayfasi',
        'pageprops': {'disambiguation': ''},
        'coordinates': [
          {'lat': 35.01, 'lon': 135.76},
        ],
      },
      '104': {
        'pageid': 104,
        'title': 'Koordinatsiz sayfa',
        'extract': 'Bu sayfanin koordinati yok.',
      },
      '105': {
        'pageid': 105,
        'title': 'Köprülü Kütüphanesi',
        'coordinates': [
          {'lat': 35.02, 'lon': 135.77},
        ],
        'extract':
            'Köprülü Kütüphanesi, 1923 yılında hizmete açılan bir '
            'kütüphanedir.',
        'fullurl': 'https://tr.wikipedia.org/wiki/K%C3%B6pr%C3%BCl%C3%BC',
      },
    },
  },
};

MockClient _client({bool turkishEmpty = false, int statusCode = 200}) {
  return MockClient((request) async {
    if (statusCode != 200) {
      return http.Response('server error', statusCode, headers: _jsonHeaders);
    }

    final isSearch = request.url.queryParameters['list'] == 'geosearch';
    final isTurkish = request.url.host.startsWith('tr.');

    if (isSearch) {
      if (isTurkish && turkishEmpty) {
        return http.Response(
          jsonEncode({
            'query': {'geosearch': []},
          }),
          200,
          headers: _jsonHeaders,
        );
      }
      return http.Response(
        jsonEncode(_geoSearchPayload()),
        200,
        headers: _jsonHeaders,
      );
    }

    return http.Response(
      jsonEncode(_detailsPayload()),
      200,
      headers: _jsonHeaders,
    );
  });
}

void main() {
  group('WikipediaPlaceProvider', () {
    test('gerçek alanları ve atıf bilgisini doldurur', () async {
      final places = await WikipediaPlaceProvider(
        client: _client(),
        languages: const ['tr'],
      ).fetchPlaces(latitude: _center.$1, longitude: _center.$2);

      expect(places, hasLength(3));

      final temple = places.firstWhere((p) => p.name == 'Kiyomizu-dera');
      expect(temple.category, 'İbadethane');
      expect(temple.source, 'Wikipedia');
      expect(temple.sourceUrl, contains('wikipedia.org'));
      expect(temple.description, contains('Buddhist'));
      expect(temple.latitude, closeTo(34.9949, 0.0001));
      expect(temple.longitude, closeTo(135.7850, 0.0001));
      expect(temple.osmId, startsWith('wikipedia:tr:'));
      expect(temple.isFood, isFalse);

      final palace = places.firstWhere(
        (p) => p.name == 'Kyoto Imperial Palace',
      );
      expect(palace.category, 'Saray');

      // "Köprülü" içindeki "köprü" kelimesi yanlış sınıflandırmamalı.
      final library = places.firstWhere((p) => p.name == 'Köprülü Kütüphanesi');
      expect(library.category, 'Gezilecek Yer');
    });

    test('anlaşmazlık sayfalarını ve koordinatsız sayfaları atlar', () async {
      final places = await WikipediaPlaceProvider(
        client: _client(),
        languages: const ['tr'],
      ).fetchPlaces(latitude: _center.$1, longitude: _center.$2);

      expect(
        places.map((place) => place.name),
        isNot(contains('Anlasmazlik sayfasi')),
      );
      expect(
        places.map((place) => place.name),
        isNot(contains('Koordinatsiz sayfa')),
      );
    });

    test('Türkçe boşsa İngilizceye düşer', () async {
      final places = await WikipediaPlaceProvider(
        client: _client(turkishEmpty: true),
        languages: const ['tr', 'en'],
      ).fetchPlaces(latitude: _center.$1, longitude: _center.$2);

      expect(places, isNotEmpty);
      expect(places.first.osmId, startsWith('wikipedia:en:'));
    });

    test('sunucu hatasında boş liste döner ve çökmez', () async {
      final places = await WikipediaPlaceProvider(
        client: _client(statusCode: 500),
        languages: const ['tr'],
      ).fetchPlaces(latitude: _center.$1, longitude: _center.$2);

      expect(places, isEmpty);
    });
  });

  group('FallbackPlaceProvider', () {
    test('birincil sağlayıcı hata verirse yedeği kullanır', () async {
      final provider = FallbackPlaceProvider(
        primary: _ThrowingProvider(),
        fallbacks: [_StaticProvider(name: 'Yedek Mekan')],
      );

      final places = await provider.fetchPlaces(
        latitude: _center.$1,
        longitude: _center.$2,
      );

      expect(places.single.name, 'Yedek Mekan');
    });

    test('birincil boş dönerse yedeği kullanır', () async {
      final provider = FallbackPlaceProvider(
        primary: _StaticProvider(places: const []),
        fallbacks: [_StaticProvider(name: 'Yedek Mekan')],
      );

      final places = await provider.fetchPlaces(
        latitude: _center.$1,
        longitude: _center.$2,
      );

      expect(places.single.name, 'Yedek Mekan');
    });

    test('tüm sağlayıcılar başarısızsa birincil hatayı fırlatır', () async {
      final provider = FallbackPlaceProvider(
        primary: _ThrowingProvider(),
        fallbacks: [_ThrowingProvider()],
      );

      expect(
        () => provider.fetchPlaces(latitude: _center.$1, longitude: _center.$2),
        throwsA(isA<AppException>()),
      );
    });
  });
}

class _ThrowingProvider implements PlaceProvider {
  @override
  Future<List<Place>> fetchPlaces({
    required double latitude,
    required double longitude,
  }) async {
    throw const AppException(
      'Sağlayıcı kapalı.',
      kind: AppErrorKind.providerUnavailable,
    );
  }
}

class _StaticProvider implements PlaceProvider {
  _StaticProvider({this.name = 'Mekan', this.places});

  final String name;
  final List<Place>? places;

  @override
  Future<List<Place>> fetchPlaces({
    required double latitude,
    required double longitude,
  }) async {
    final preset = places;
    if (preset != null) return preset;

    return [
      Place(
        name: name,
        category: 'Müze',
        description: 'Test mekanı.',
        latitude: latitude,
        longitude: longitude,
        osmId: 'test/1',
      ),
    ];
  }
}
