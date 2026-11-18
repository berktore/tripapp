import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../models/trip_plan.dart';

class DestinationPlacesService {
  static const String _userAgent = 'TripApp/1.0';

  static const List<String> _servers = [
    'overpass-api.de',
    'overpass.kumi.systems',
  ];

  static const List<String> _times = [
    '09:00',
    '11:00',
    '13:30',
    '15:30',
    '17:00',
  ];

  Future<List<ItineraryDay>> buildItinerary({
    required String destination,
    required int dayCount,
    required List<String> styles,
  }) async {
    if (destination.trim().isEmpty) {
      throw ArgumentError('Destinasyon boş olamaz.');
    }

    if (dayCount < 1) {
      throw ArgumentError('Gezi en az bir gün olmalıdır.');
    }

    final location = await _findLocation(destination);
    final places = await _findPlaces(location);

    if (places.isEmpty) {
      throw Exception('$destination için yeterli gezi noktası bulunamadı.');
    }

    return _createDailyItinerary(
      destination: destination,
      places: places,
      dayCount: dayCount,
      styles: styles,
    );
  }

  Future<Map<String, dynamic>> _findLocation(String destination) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': destination,
      'format': 'jsonv2',
      'limit': '1',
      'addressdetails': '1',
    });

    final response = await http
        .get(uri, headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('Destinasyon konumu alınamadı.');
    }

    final results = jsonDecode(response.body) as List<dynamic>;

    if (results.isEmpty) {
      throw Exception('Destinasyon haritada bulunamadı.');
    }

    return Map<String, dynamic>.from(results.first as Map);
  }

  Future<List<_Place>> _findPlaces(Map<String, dynamic> location) async {
    final bounds = location['boundingbox'] as List<dynamic>?;

    if (bounds == null || bounds.length < 4) {
      throw Exception('Destinasyon harita sınırları bulunamadı.');
    }

    final south = double.parse(bounds[0].toString());
    final north = double.parse(bounds[1].toString());
    final west = double.parse(bounds[2].toString());
    final east = double.parse(bounds[3].toString());

    final area = '($south,$west,$north,$east)';

    // Önce gerçek gezi ve keşif noktalarını getir.
    // Restoranları ayrı sorguluyoruz; böylece sonuçları dolduramazlar.
    final attractionQuery =
        '''
[out:json][timeout:40];
(
  node["tourism"~"attraction|museum|viewpoint|zoo|aquarium"]$area;
  way["tourism"~"attraction|museum|viewpoint|zoo|aquarium"]$area;
  relation["tourism"~"attraction|museum|viewpoint|zoo|aquarium"]$area;

  node["historic"~"castle|archaeological_site|monument|memorial|ruins|fort|city_gate|tomb|church|mosque|temple"]$area;
  way["historic"~"castle|archaeological_site|monument|memorial|ruins|fort|city_gate|tomb|church|mosque|temple"]$area;
  relation["historic"~"castle|archaeological_site|monument|memorial|ruins|fort|city_gate|tomb|church|mosque|temple"]$area;

  node["leisure"="park"]$area;
  way["leisure"="park"]$area;

  node["natural"="beach"]$area;
  way["natural"="beach"]$area;

  node["waterway"="waterfall"]$area;
);
out center tags 100;
''';

    final foodQuery =
        '''
[out:json][timeout:30];
(
  node["amenity"~"restaurant|cafe"]["name"]$area;
  way["amenity"~"restaurant|cafe"]["name"]$area;
);
out center tags 40;
''';

    final attractions = await _queryPlaces(attractionQuery);
    final restaurants = await _queryPlaces(foodQuery);

    final unique = <String, _Place>{};

    for (final place in [...attractions, ...restaurants]) {
      unique.putIfAbsent(place.osmId, () => place);
    }

    return unique.values.toList();
  }

  Future<List<_Place>> _queryPlaces(String query) async {
    for (final server in _servers) {
      try {
        final uri = Uri.https(server, '/api/interpreter');

        final response = await http
            .post(
              uri,
              body: {'data': query},
              headers: {'User-Agent': _userAgent},
            )
            .timeout(const Duration(seconds: 50));

        if (response.statusCode != 200) {
          continue;
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final elements = data['elements'] as List<dynamic>? ?? [];

        final places = <_Place>[];

        for (final element in elements) {
          final map = Map<String, dynamic>.from(element as Map);

          final tags = Map<String, dynamic>.from(map['tags'] as Map? ?? {});

          final name = tags['name']?.toString().trim() ?? '';

          if (name.isEmpty) continue;

          final center = map['center'] == null
              ? null
              : Map<String, dynamic>.from(map['center'] as Map);

          final lat = map['lat'] ?? center?['lat'];
          final lon = map['lon'] ?? center?['lon'];

          if (lat is! num || lon is! num) continue;

          final category = _getCategory(tags);

          if (category == null) continue;

          places.add(
            _Place(
              name: name,
              category: category,
              description: _getDescription(category, tags),
              latitude: lat.toDouble(),
              longitude: lon.toDouble(),
              osmId: '${map['type']}/${map['id']}',
              tags: tags,
            ),
          );
        }

        return places;
      } catch (_) {
        continue;
      }
    }

    return [];
  }

  String? _getCategory(Map<String, dynamic> tags) {
    final tourism = tags['tourism']?.toString();
    final historic = tags['historic']?.toString();
    final amenity = tags['amenity']?.toString();
    final leisure = tags['leisure']?.toString();
    final natural = tags['natural']?.toString();
    final waterway = tags['waterway']?.toString();

    if (tourism == 'museum') return 'Müze';
    if (tourism == 'viewpoint') return 'Manzara';
    if (tourism == 'zoo' || tourism == 'aquarium') {
      return 'Eğlence';
    }
    if (tourism == 'attraction') return 'Turistik Yer';

    if (historic != null) return 'Tarihi Yer';

    if (waterway == 'waterfall') return 'Şelale';
    if (natural == 'beach') return 'Plaj';

    if (leisure == 'park') return 'Park';

    if (amenity == 'restaurant') return 'Restoran';
    if (amenity == 'cafe') return 'Kafe';

    return null;
  }

  String _getDescription(String category, Map<String, dynamic> tags) {
    final address = tags['addr:street']?.toString();

    final descriptions = {
      'Müze': 'Kültür ve tarih keşfi için ziyaret edilebilecek bir müze.',
      'Manzara': 'Manzara izlemek ve fotoğraf çekmek için bir nokta.',
      'Eğlence': 'Keyifli vakit geçirebileceğin bir aktivite noktası.',
      'Turistik Yer': 'Destinasyonun turistik keşif noktalarından biri.',
      'Tarihi Yer': 'Bölgenin tarihi dokusunu keşfedebileceğin bir yer.',
      'Şelale': 'Doğal güzelliğiyle öne çıkan bir şelale.',
      'Plaj': 'Deniz ve sahil keyfi için bir durak.',
      'Park': 'Dinlenmek ve doğayla vakit geçirmek için bir alan.',
      'Restoran': 'Yemek molası verebileceğin bir restoran.',
      'Kafe': 'Dinlenmek için kahve molası verebileceğin bir kafe.',
    };

    final description = descriptions[category] ?? 'Keşfedilebilecek bir nokta.';

    if (address != null && address.isNotEmpty) {
      return '$description Adres: $address';
    }

    return description;
  }

  List<ItineraryDay> _createDailyItinerary({
    required String destination,
    required List<_Place> places,
    required int dayCount,
    required List<String> styles,
  }) {
    final attractions = places.where((place) => !_isFood(place)).toList();

    final food = places.where(_isFood).toList();

    attractions.sort(
      (a, b) => _styleScore(b, styles).compareTo(_styleScore(a, styles)),
    );

    // Her gün en fazla dört ana gezi noktası.
    // Kategori tekrarlarını azaltmak için farklı günlere dengeli dağıt.
    final dailyPlaces = List.generate(dayCount, (_) => <_Place>[]);

    final categoryCounts = List.generate(dayCount, (_) => <String, int>{});

    for (final place in attractions) {
      final eligibleDays = <int>[];

      for (var day = 0; day < dayCount; day++) {
        if (dailyPlaces[day].length < 4) {
          eligibleDays.add(day);
        }
      }

      if (eligibleDays.isEmpty) break;

      eligibleDays.sort((a, b) {
        final countA = dailyPlaces[a].length;
        final countB = dailyPlaces[b].length;

        final categoryA = categoryCounts[a][place.category] ?? 0;
        final categoryB = categoryCounts[b][place.category] ?? 0;

        final scoreA = countA * 10 + categoryA * 5;
        final scoreB = countB * 10 + categoryB * 5;

        return scoreA.compareTo(scoreB);
      });

      final selectedDay = eligibleDays.first;

      dailyPlaces[selectedDay].add(place);

      categoryCounts[selectedDay][place.category] =
          (categoryCounts[selectedDay][place.category] ?? 0) + 1;
    }

    // Restoran ve kafeleri ana gezi noktalarından ayrı dağıt.
    // Her gün toplamda en fazla bir yemek durağı.
    food.sort((a, b) => _foodScore(b).compareTo(_foodScore(a)));

    for (var day = 0; day < dayCount; day++) {
      if (food.isEmpty) break;

      if (dailyPlaces[day].isNotEmpty && dailyPlaces[day].length < 5) {
        dailyPlaces[day].add(food.removeAt(0));
      }
    }

    final days = <ItineraryDay>[];

    for (var day = 0; day < dayCount; day++) {
      final orderedPlaces = _orderByDistance(dailyPlaces[day]);

      final stops = <ItineraryStop>[];

      for (var i = 0; i < orderedPlaces.length; i++) {
        final place = orderedPlaces[i];

        stops.add(
          ItineraryStop(
            time: _times[i],
            title: place.name,
            description: place.description,
            category: place.category,
            latitude: place.latitude,
            longitude: place.longitude,
            osmId: place.osmId,
          ),
        );
      }

      days.add(
        ItineraryDay(
          dayNumber: day + 1,
          title: '$destination - ${day + 1}. Gün Keşfi',
          stops: stops,
        ),
      );
    }

    return days;
  }

  bool _isFood(_Place place) {
    return place.category == 'Restoran' || place.category == 'Kafe';
  }

  int _foodScore(_Place place) {
    return place.category == 'Restoran' ? 2 : 1;
  }

  int _styleScore(_Place place, List<String> styles) {
    final category = place.category.toLowerCase();
    final tags = place.tags;

    var score = 0;

    for (final style in styles) {
      final normalized = style.toLowerCase();

      if ((normalized.contains('kültür') || normalized.contains('tarih')) &&
          (category.contains('tarih') || category.contains('müze'))) {
        score += 5;
      }

      if ((normalized.contains('doğa') || normalized.contains('macera')) &&
          (category.contains('park') ||
              category.contains('manzara') ||
              category.contains('şelale') ||
              category.contains('plaj'))) {
        score += 5;
      }

      if ((normalized.contains('gastronomi') || normalized.contains('yemek')) &&
          _isFood(place)) {
        score += 5;
      }

      if (normalized.contains('eğlence') && category.contains('eğlence')) {
        score += 5;
      }

      if (normalized.contains('deniz') &&
          (tags['natural'] == 'beach' || tags['leisure'] == 'beach_resort')) {
        score += 5;
      }
    }

    return score;
  }

  List<_Place> _orderByDistance(List<_Place> places) {
    if (places.length < 2) {
      return List<_Place>.from(places);
    }

    final remaining = List<_Place>.from(places);
    final ordered = <_Place>[];

    // İlk durak olarak en yüksek öncelikli mekanı seç.
    remaining.sort((a, b) => _placePriority(b).compareTo(_placePriority(a)));

    var current = remaining.removeAt(0);
    ordered.add(current);

    // Sonraki durakları mevcut konuma en yakın olacak şekilde seç.
    while (remaining.isNotEmpty) {
      remaining.sort(
        (a, b) => _distance(current, a).compareTo(_distance(current, b)),
      );

      current = remaining.removeAt(0);
      ordered.add(current);
    }

    return ordered;
  }

  int _placePriority(_Place place) {
    switch (place.category) {
      case 'Tarihi Yer':
      case 'Müze':
        return 5;
      case 'Şelale':
      case 'Plaj':
      case 'Manzara':
      case 'Park':
        return 4;
      case 'Turistik Yer':
      case 'Eğlence':
        return 3;
      default:
        return 1;
    }
  }

  double _distance(_Place a, _Place b) {
    const earthRadius = 6371.0;

    final lat1 = _radians(a.latitude);
    final lat2 = _radians(b.latitude);
    final deltaLat = _radians(b.latitude - a.latitude);
    final deltaLon = _radians(b.longitude - a.longitude);

    final value =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);

    final distance = 2 * math.atan2(math.sqrt(value), math.sqrt(1 - value));

    return earthRadius * distance;
  }

  double _radians(double degrees) {
    return degrees * math.pi / 180;
  }
}

class _Place {
  final String name;
  final String category;
  final String description;
  final double latitude;
  final double longitude;
  final String osmId;
  final Map<String, dynamic> tags;

  const _Place({
    required this.name,
    required this.category,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.osmId,
    required this.tags,
  });
}
