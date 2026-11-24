import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_exception.dart';
import '../models/place.dart';
import 'place_provider.dart';

/// Geoapify Places API üzerinden işletme ve gezi noktası arar.
///
/// API anahtarı `--dart-define=GEOAPIFY_API_KEY=...` ile verilir. Web
/// yayını öncesinde anahtar Geoapify panelinden alan adıyla sınırlandırılmalıdır.
class GeoapifyPlaceProvider implements PlaceProvider {
  GeoapifyPlaceProvider({http.Client? client, String? apiKey})
    : _client = client ?? http.Client(),
      _apiKey = apiKey ?? const String.fromEnvironment('GEOAPIFY_API_KEY');

  final http.Client _client;
  final String _apiKey;

  static const _categories = [
    'tourism',
    'entertainment',
    'leisure',
    'commercial',
    'catering',
    'adult.nightclub',
  ];

  @override
  Future<List<Place>> fetchPlaces({
    required double latitude,
    required double longitude,
  }) async {
    if (_apiKey.isEmpty) {
      throw const AppException(
        'Geoapify API anahtarı yapılandırılmadı.',
        kind: AppErrorKind.providerUnavailable,
      );
    }

    final uri = Uri.https('api.geoapify.com', '/v2/places', {
      'categories': _categories.join(','),
      'filter': 'circle:$longitude,$latitude,6000',
      'bias': 'proximity:$longitude,$latitude',
      'limit': '200',
      'lang': 'tr',
      'apiKey': _apiKey,
    });

    try {
      final response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw AppException(
          'Geoapify mekân araması yanıt veremedi.',
          kind: AppErrorKind.providerUnavailable,
          details: 'HTTP ${response.statusCode}',
        );
      }
      return _parse(response.body);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException(
        'Geoapify mekân aramasına ulaşılamadı.',
        kind: AppErrorKind.providerUnavailable,
        details: error.toString(),
      );
    }
  }

  List<Place> _parse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['features'] is! List) return const [];

    final places = <Place>[];
    for (final rawFeature in (decoded['features'] as List).whereType<Map>()) {
      final properties = rawFeature['properties'];
      final geometry = rawFeature['geometry'];
      if (properties is! Map || geometry is! Map) continue;

      final coordinates = geometry['coordinates'];
      if (coordinates is! List || coordinates.length < 2) continue;
      final longitude = coordinates[0];
      final latitude = coordinates[1];
      if (latitude is! num || longitude is! num) continue;

      final name = properties['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final categories = (properties['categories'] as List? ?? const [])
          .map((category) => category.toString())
          .toList();
      final category = _category(categories);
      if (category == null) continue;

      final placeId = properties['place_id']?.toString() ?? name;
      final description = properties['formatted']?.toString().trim();
      places.add(
        Place(
          name: name,
          category: category,
          description: description == null || description.isEmpty
              ? _description(category)
              : description,
          latitude: latitude.toDouble(),
          longitude: longitude.toDouble(),
          osmId: 'geoapify:$placeId',
          openingHours: properties['opening_hours']?.toString(),
          tags: {'geoapify_categories': categories},
          source: 'Geoapify',
        ),
      );
    }
    return places;
  }

  String? _category(List<String> categories) {
    bool has(String prefix) => categories.any(
      (category) => category == prefix || category.startsWith('$prefix.'),
    );

    if (has('adult.nightclub') ||
        has('catering.bar') ||
        has('catering.pub') ||
        has('catering.taproom')) {
      return 'Gece Hayatı';
    }
    if (has('catering.restaurant') || has('catering.food_court')) {
      return 'Restoran';
    }
    if (has('catering.cafe')) return 'Kafe';
    if (has('entertainment.museum')) return 'Müze';
    if (has('leisure.park')) return 'Park';
    if (has('beach')) return 'Plaj';
    if (has('commercial')) return 'Alışveriş';
    if (has('tourism') || has('entertainment') || has('leisure')) {
      return 'Turistik Yer';
    }
    return null;
  }

  String _description(String category) => switch (category) {
    'Gece Hayatı' => 'Akşamı değerlendirmek için bir eğlence mekânı.',
    'Restoran' => 'Gezi sırasında yemek molası verebileceğin bir restoran.',
    'Kafe' => 'Dinlenmek ve mola vermek için uğrayabileceğin bir kafe.',
    'Alışveriş' => 'Alışveriş yapabileceğin bir mağaza veya ticari alan.',
    _ => 'Bölgede ziyaret edilebilecek bir gezi noktası.',
  };
}
