import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/trip_plan.dart';
import 'itinerary_distribution_service.dart';
import 'place_filter_service.dart';
import 'place_scoring_service.dart';

class DestinationPlacesService {
  static const String _userAgent = 'TripApp/1.0';

  static const List<String> _servers = [
    'overpass-api.de',
    'overpass.kumi.systems',
    'overpass.private.coffee',
  ];

  static const List<String> _times = [
    '09:00',
    '11:00',
    '13:30',
    '15:30',
    '17:00',
  ];

  static const int _searchRadiusMeters = 25000;
  static const double _maxDistanceKm = 25;

  final PlaceFilterService _filterService = const PlaceFilterService();
  final PlaceScoringService _scoringService = const PlaceScoringService();
  final ItineraryDistributionService _distributionService =
      const ItineraryDistributionService();

  static const Map<String, String> _destinationCountries = {
    'kapadokya': 'tr',
    'cappadocia': 'tr',
    'istanbul': 'tr',
    'antalya': 'tr',
    'ankara': 'tr',
    'izmir': 'tr',
    'bodrum': 'tr',
    'nevsehir': 'tr',
    'goreme': 'tr',
    'santorini': 'gr',
    'atina': 'gr',
    'athens': 'gr',
    'mykonos': 'gr',
    'rhodes': 'gr',
    'kyoto': 'jp',
    'tokyo': 'jp',
    'osaka': 'jp',
    'nara': 'jp',
    'roma': 'it',
    'rome': 'it',
    'venedik': 'it',
    'venice': 'it',
    'floransa': 'it',
    'florence': 'it',
    'milano': 'it',
    'milan': 'it',
    'paris': 'fr',
    'nice': 'fr',
    'lyon': 'fr',
    'londra': 'gb',
    'london': 'gb',
    'edinburgh': 'gb',
    'berlin': 'de',
    'munih': 'de',
    'munich': 'de',
    'hamburg': 'de',
    'barcelona': 'es',
    'madrid': 'es',
    'seville': 'es',
    'sevilla': 'es',
    'amsterdam': 'nl',
    'rotterdam': 'nl',
    'zurich': 'ch',
    'geneva': 'ch',
    'cologne': 'de',
    'prague': 'cz',
    'budapest': 'hu',
    'vienna': 'at',
    'wien': 'at',
    'new york': 'us',
    'los angeles': 'us',
    'san francisco': 'us',
    'las vegas': 'us',
    'miami': 'us',
    'chicago': 'us',
    'toronto': 'ca',
    'vancouver': 'ca',
    'bali': 'id',
    'jakarta': 'id',
    'dubai': 'ae',
    'abu dhabi': 'ae',
    'bangkok': 'th',
    'phuket': 'th',
    'singapore': 'sg',
    'seoul': 'kr',
    'busan': 'kr',
    'sydney': 'au',
    'melbourne': 'au',
    'cairo': 'eg',
    'marrakech': 'ma',
    'cape town': 'za',
    'lisbon': 'pt',
    'porto': 'pt',
    'brussels': 'be',
    'bruges': 'be',
    'copenhagen': 'dk',
    'stockholm': 'se',
    'oslo': 'no',
    'helsinki': 'fi',
    'moscow': 'ru',
    'st petersburg': 'ru',
  };

  static const Map<String, String> _countryNames = {
    'tr': 'Türkiye',
    'gr': 'Yunanistan',
    'jp': 'Japonya',
    'it': 'İtalya',
    'fr': 'Fransa',
    'gb': 'Birleşik Krallık',
    'de': 'Almanya',
    'es': 'İspanya',
    'nl': 'Hollanda',
    'ch': 'İsviçre',
    'cz': 'Çekya',
    'hu': 'Macaristan',
    'at': 'Avusturya',
    'us': 'Amerika Birleşik Devletleri',
    'ca': 'Kanada',
    'id': 'Endonezya',
    'ae': 'Birleşik Arap Emirlikleri',
    'th': 'Tayland',
    'sg': 'Singapur',
    'kr': 'Güney Kore',
    'au': 'Avustralya',
    'eg': 'Mısır',
    'ma': 'Fas',
    'za': 'Güney Afrika',
    'pt': 'Portekiz',
    'be': 'Belçika',
    'dk': 'Danimarka',
    'se': 'İsveç',
    'no': 'Norveç',
    'fi': 'Finlandiya',
    'ru': 'Rusya',
  };

  // ------------------------------------------------------------
  // ANA PLANLAMA
  // ------------------------------------------------------------

  Future<List<ItineraryDay>> buildItinerary({
    required String destination,
    required int dayCount,
    required List<String> styles,
    String budget = 'Orta',
  }) async {
    final cleanDestination = destination.trim();

    if (cleanDestination.isEmpty) {
      throw ArgumentError('Destinasyon boş olamaz.');
    }

    if (dayCount < 1 || dayCount > 30) {
      throw ArgumentError(
        'Gezi süresi 1 ile 30 gün arasında olmalıdır.',
      );
    }

    final location = await _findLocation(cleanDestination);
    final places = await _findPlaces(location);

    if (places.isEmpty) {
      throw Exception(
        '$cleanDestination çevresinde kullanılabilir gezi noktası '
        'bulunamadı. Lütfen daha sonra tekrar dene.',
      );
    }

    final attractions = places.where((p) => !_isFood(p)).toList();

    if (attractions.isEmpty) {
      throw Exception(
        '$cleanDestination için yeterli turistik mekân bulunamadı.',
      );
    }

    return _createDailyItinerary(
      destination: cleanDestination,
      places: places,
      dayCount: dayCount,
      styles: styles,
      budget: budget,
    );
  }

  // ------------------------------------------------------------
  // NORMALİZASYON VE DESTİNASYON
  // ------------------------------------------------------------

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _getCountryCode(String destination) {
    final normalized = _normalize(destination);

    if (_destinationCountries.containsKey(normalized)) {
      return _destinationCountries[normalized];
    }

    final firstPart = normalized.split(',').first.trim();
    return _destinationCountries[firstPart];
  }

  bool _isCappadocia(String destination) {
    final value = _normalize(destination);
    return value.contains('kapadokya') ||
        value.contains('cappadocia');
  }

  // ------------------------------------------------------------
  // KONUM BULMA
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> _findLocation(
    String destination,
  ) async {
    final countryCode = _getCountryCode(destination);
    final isCappadocia = _isCappadocia(destination);
    final countryName =
        countryCode == null ? null : _countryNames[countryCode];

    final query = isCappadocia
        ? 'Kapadokya, Nevşehir, Türkiye'
        : countryName != null
            ? '$destination, $countryName'
            : destination;

    final parameters = <String, String>{
      'q': query,
      'format': 'jsonv2',
      'limit': '10',
      'addressdetails': '1',
      'accept-language': 'tr',
    };

    if (countryCode != null) {
      parameters['countrycodes'] = countryCode;
    }

    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      parameters,
    );

    final response = await http.get(
      uri,
      headers: {
        'User-Agent': _userAgent,
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception(
        'Konum servisi yanıt vermedi: ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List) {
      throw Exception('Konum servisinden geçersiz veri geldi.');
    }

    final candidates = decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) {
          final lat = double.tryParse(item['lat']?.toString() ?? '');
          final lon = double.tryParse(item['lon']?.toString() ?? '');
          final address = item['address'];

          if (lat == null || lon == null || address is! Map) {
            return false;
          }

          if (countryCode != null) {
            final actualCode =
                address['country_code']?.toString().toLowerCase();

            if (actualCode != countryCode) return false;
          }

          if (isCappadocia) {
            return lat >= 37.3 &&
                lat <= 39.5 &&
                lon >= 33.0 &&
                lon <= 36.5;
          }

          final displayName = _normalize(
            item['display_name']?.toString() ?? '',
          );

          final firstPart =
              _normalize(destination.split(',').first);

          return displayName.contains(firstPart);
        }).toList();

    if (candidates.isEmpty) {
      throw Exception(
        '$destination için doğru ülkede konum bulunamadı.',
      );
    }

    candidates.sort((a, b) {
      final nameA = _normalize(a['display_name']?.toString() ?? '');
      final nameB = _normalize(b['display_name']?.toString() ?? '');
      final target = _normalize(destination.split(',').first);

      final scoreA = nameA.startsWith(target) ? 1 : 0;
      final scoreB = nameB.startsWith(target) ? 1 : 0;

      return scoreB.compareTo(scoreA);
    });

    return candidates.first;
  }

  // ------------------------------------------------------------
  // OVERPASS MEKÂN ARAMA
  // ------------------------------------------------------------

  Future<List<_Place>> _findPlaces(
    Map<String, dynamic> location,
  ) async {
    final latitude = double.tryParse(location['lat'].toString());
    final longitude = double.tryParse(location['lon'].toString());

    if (latitude == null || longitude == null) {
      throw Exception('Destinasyon koordinatları okunamadı.');
    }

    final area =
        '(around:$_searchRadiusMeters,$latitude,$longitude)';

    final attractionQuery = '''
[out:json][timeout:60];
(
  node$area["tourism"~"attraction|museum|viewpoint|zoo|aquarium|artwork|gallery"];
  way$area["tourism"~"attraction|museum|viewpoint|zoo|aquarium|artwork|gallery"];
  relation$area["tourism"~"attraction|museum|viewpoint|zoo|aquarium|artwork|gallery"];

  node$area["amenity"="place_of_worship"];
  way$area["amenity"="place_of_worship"];
  relation$area["amenity"="place_of_worship"];

  node$area["historic"];
  way$area["historic"];
  relation$area["historic"];

  node$area["leisure"~"park|garden|nature_reserve"];
  way$area["leisure"~"park|garden|nature_reserve"];
  relation$area["leisure"~"park|garden|nature_reserve"];

  node$area["amenity"="marketplace"];
  way$area["amenity"="marketplace"];

  node$area["shop"~"mall|department_store|marketplace"];
  way$area["shop"~"mall|department_store|marketplace"];

  node$area["natural"~"beach|waterfall"];
  way$area["natural"~"beach|waterfall"];

  node$area["waterway"="waterfall"];
  way$area["waterway"="waterfall"];
);
out center tags 300;
''';

    final foodQuery = '''
[out:json][timeout:40];
(
  node$area["amenity"~"restaurant|cafe|food_court"];
  way$area["amenity"~"restaurant|cafe|food_court"];
  node$area["shop"="bakery"];
  way$area["shop"="bakery"];
);
out center tags 100;
''';

    final attractions = await _queryPlaces(
      attractionQuery,
      centerLatitude: latitude,
      centerLongitude: longitude,
    );

    final restaurants = await _queryPlaces(
      foodQuery,
      centerLatitude: latitude,
      centerLongitude: longitude,
    );

    return _filterService.filter<_Place>(
      places: [...attractions, ...restaurants],
      getName: (place) => place.name,
      getId: (place) => place.osmId,
      getLatitude: (place) => place.latitude,
      getLongitude: (place) => place.longitude,
      getCategory: (place) => place.category,
    );
  }

  Future<List<_Place>> _queryPlaces(
    String query, {
    required double centerLatitude,
    required double centerLongitude,
  }) async {
    for (final server in _servers) {
      try {
        final uri = Uri.https(server, '/api/interpreter');

        final response = await http.post(
          uri,
          body: {'data': query},
          headers: {
            'User-Agent': _userAgent,
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 60));

        if (response.statusCode != 200) continue;

        final decoded = jsonDecode(response.body);

        if (decoded is! Map<String, dynamic>) continue;

        final elements = decoded['elements'] as List<dynamic>? ?? [];
        final places = <_Place>[];

        for (final element in elements) {
          if (element is! Map) continue;

          final map = Map<String, dynamic>.from(element);
          final tags = Map<String, dynamic>.from(
            map['tags'] as Map? ?? {},
          );

          final name = _getReadableName(tags);
          if (name.isEmpty) continue;

          final center = map['center'] is Map
              ? Map<String, dynamic>.from(map['center'] as Map)
              : null;

          final lat = map['lat'] ?? center?['lat'];
          final lon = map['lon'] ?? center?['lon'];

          if (lat is! num || lon is! num) continue;

          final placeLatitude = lat.toDouble();
          final placeLongitude = lon.toDouble();

          final distance = _filterService.distanceKm(
            latitude1: centerLatitude,
            longitude1: centerLongitude,
            latitude2: placeLatitude,
            longitude2: placeLongitude,
          );

          if (distance > _maxDistanceKm) continue;

          final category = _getCategory(tags);
          if (category == null) continue;

          places.add(
            _Place(
              name: name,
              category: category,
              description: _getDescription(category, tags),
              latitude: placeLatitude,
              longitude: placeLongitude,
              osmId: '${map['type']}/${map['id']}',
              tags: tags,
            ),
          );
        }

        if (places.isNotEmpty) return places;
      } catch (_) {
        // Sunucu hata verirse sıradaki Overpass sunucusunu dene.
        continue;
      }
    }

    return [];
  }

  // ------------------------------------------------------------
  // MEKÂN İSİMLERİ
  // ------------------------------------------------------------

  String _getReadableName(Map<String, dynamic> tags) {
    final candidates = [
      tags['name:tr'],
      tags['name:en'],
      tags['name:ja-Latn'],
      tags['name:ja_rm'],
      tags['int_name'],
      tags['name:romaji'],
      tags['official_name:en'],
      tags['official_name'],
      tags['name'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';

      if (value.isEmpty) continue;
      if (_containsJapaneseCharacters(value)) continue;

      return value;
    }

    return '';
  }

  bool _containsJapaneseCharacters(String value) {
    return RegExp(
      r'[\u3040-\u30FF\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]',
    ).hasMatch(value);
  }

  // ------------------------------------------------------------
  // KATEGORİLER
  // ------------------------------------------------------------

  String? _getCategory(Map<String, dynamic> tags) {
    final tourism = tags['tourism']?.toString();
    final historic = tags['historic']?.toString();
    final amenity = tags['amenity']?.toString();
    final religion = tags['religion']?.toString();
    final building = tags['building']?.toString();
    final leisure = tags['leisure']?.toString();
    final natural = tags['natural']?.toString();
    final waterway = tags['waterway']?.toString();
    final shop = tags['shop']?.toString();

    if (amenity == 'place_of_worship' || building == 'temple') {
      if (religion == 'shinto') return 'Şinto Mabedi';
      if (religion == 'buddhist') return 'Budist Tapınağı';
      return 'İbadethane';
    }

    if (historic == 'castle') return 'Kale';
    if (historic == 'monument' || historic == 'memorial') {
      return 'Anıt';
    }
    if (historic == 'archaeological_site') {
      return 'Arkeolojik Alan';
    }
    if (historic == 'ruins') return 'Tarihî Kalıntı';
    if (historic == 'tomb') return 'Mezar Anıtı';

    if (leisure == 'garden' || tourism == 'garden') {
      return 'Bahçe';
    }
    if (leisure == 'nature_reserve') return 'Doğa Alanı';
    if (leisure == 'park') return 'Park';

    if (tourism == 'museum') return 'Müze';
    if (tourism == 'viewpoint') return 'Manzara';
    if (tourism == 'zoo' || tourism == 'aquarium') {
      return 'Eğlence';
    }
    if (tourism == 'gallery') return 'Sanat Galerisi';
    if (tourism == 'attraction' || tourism == 'artwork') {
      return 'Turistik Yer';
    }

    if (amenity == 'marketplace' || shop == 'marketplace') {
      return 'Pazar';
    }
    if (shop == 'mall' || shop == 'department_store') {
      return 'Alışveriş';
    }

    if (waterway == 'waterfall' || natural == 'waterfall') {
      return 'Şelale';
    }
    if (natural == 'beach') return 'Plaj';

    if (amenity == 'restaurant' || amenity == 'food_court') {
      return 'Restoran';
    }
    if (amenity == 'cafe' || shop == 'bakery') return 'Kafe';

    // Diğer tarihî etiketleri genel tarihî yer olarak sınıflandır.
    if (historic != null) return 'Tarihî Yer';

    return null;
  }

  // ------------------------------------------------------------
  // TÜRKÇE AÇIKLAMALAR
  // ------------------------------------------------------------

  String _getDescription(
    String category,
    Map<String, dynamic> tags,
  ) {
    final turkishDescription =
        tags['description:tr']?.toString().trim();

    if (turkishDescription != null &&
        turkishDescription.isNotEmpty) {
      return turkishDescription;
    }

    const descriptions = <String, String>{
      'Şinto Mabedi':
          'Japon Şinto inancına ait geleneksel bir ibadet alanı.',
      'Budist Tapınağı':
          'Budist mimarisini ve Japon kültürünü keşfedebileceğin bir tapınak.',
      'İbadethane':
          'Bölgenin inanç ve kültür mirasının bir parçası.',
      'Kale':
          'Bölgenin savunma tarihini yansıtan tarihî bir yapı.',
      'Anıt':
          'Tarihî bir olayı veya kişiyi anmak için yapılmış bir eser.',
      'Arkeolojik Alan':
          'Geçmiş uygarlıklardan izler taşıyan arkeolojik bir alan.',
      'Tarihî Kalıntı':
          'Geçmiş dönemlerden günümüze ulaşan tarihî kalıntılar.',
      'Mezar Anıtı':
          'Tarihî ve kültürel öneme sahip bir anıt mezar.',
      'Tarihî Yer':
          'Bölgenin tarihî mirasını yansıtan bir ziyaret noktası.',
      'Bahçe':
          'Peyzaj düzenlemesi ve doğal güzelliğiyle öne çıkan bir bahçe.',
      'Park':
          'Açık havada dinlenmek ve doğayla vakit geçirmek için bir alan.',
      'Doğa Alanı':
          'Doğal yaşamı ve çevreyi keşfedebileceğin bir alan.',
      'Müze':
          'Sanat, kültür veya tarih koleksiyonlarını keşfedebileceğin bir müze.',
      'Manzara':
          'Çevreyi izlemek ve fotoğraf çekmek için bir seyir noktası.',
      'Eğlence':
          'Keyifli vakit geçirmek için ziyaret edilebilecek bir yer.',
      'Sanat Galerisi':
          'Sanat eserlerini ve yerel sergileri keşfedebileceğin bir galeri.',
      'Turistik Yer':
          'Destinasyonun ziyaret edilebilecek turistik noktalarından biri.',
      'Pazar':
          'Yerel ürünleri ve bölgenin günlük yaşamını keşfedebileceğin bir pazar.',
      'Alışveriş':
          'Mağazaları ve alışveriş alanlarını keşfedebileceğin bir nokta.',
      'Şelale':
          'Doğal su akışı ve çevresindeki manzarayla öne çıkan bir nokta.',
      'Plaj':
          'Deniz ve sahil keyfi için ziyaret edilebilecek bir alan.',
      'Restoran':
          'Gezi sırasında yemek molası verebileceğin bir restoran.',
      'Kafe':
          'Dinlenmek ve mola vermek için uğrayabileceğin bir kafe.',
    };

    return descriptions[category] ?? 'Ziyaret edilebilecek bir nokta.';
  }

  // ------------------------------------------------------------
  // GÜNLÜK GEZİ PLANI
  // ------------------------------------------------------------

  List<ItineraryDay> _createDailyItinerary({
    required String destination,
    required List<_Place> places,
    required int dayCount,
    required List<String> styles,
    required String budget,
  }) {
    final attractions = places.where((p) => !_isFood(p)).toList();
    final food = places.where(_isFood).toList();

    int scorePlace(_Place place) {
      return _scoringService.score(
        category: place.category,
        tags: place.tags,
        styles: styles,
        budget: budget,
      );
    }

    final dailyPlaces = _distributionService.distribute<_Place>(
      places: attractions,
      dayCount: dayCount,
      getLatitude: (place) => place.latitude,
      getLongitude: (place) => place.longitude,
      getScore: scorePlace,
      getCategory: (place) => place.category,
      maxPlacesPerDay: 4,
    );

    // Her güne mümkünse bir restoran veya kafe ekle.
    final usedFoodIds = <String>{};

    for (var day = 0; day < dailyPlaces.length; day++) {
      final dayPlaces = dailyPlaces[day];

      if (dayPlaces.isEmpty || food.isEmpty) continue;

      final centerLatitude = _average(
        dayPlaces.map((p) => p.latitude).toList(),
      );

      final centerLongitude = _average(
        dayPlaces.map((p) => p.longitude).toList(),
      );

      final availableFood = food
          .where((place) => !usedFoodIds.contains(place.osmId))
          .toList();

      if (availableFood.isEmpty) continue;

      availableFood.sort((a, b) {
        final distanceA = _filterService.distanceKm(
          latitude1: centerLatitude,
          longitude1: centerLongitude,
          latitude2: a.latitude,
          longitude2: a.longitude,
        );

        final distanceB = _filterService.distanceKm(
          latitude1: centerLatitude,
          longitude1: centerLongitude,
          latitude2: b.latitude,
          longitude2: b.longitude,
        );

        return distanceA.compareTo(distanceB);
      });

      final selectedFood = availableFood.first;
      dayPlaces.add(selectedFood);
      usedFoodIds.add(selectedFood.osmId);
    }

    final days = <ItineraryDay>[];

    for (var day = 0; day < dayCount; day++) {
      final dayPlaces = day < dailyPlaces.length
          ? dailyPlaces[day]
          : <_Place>[];

      final orderedPlaces = _orderByDistance(dayPlaces);
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
    return place.category == 'Restoran' ||
        place.category == 'Kafe';
  }

  // ------------------------------------------------------------
  // GÜNLÜK ROTA SIRALAMASI
  // ------------------------------------------------------------

  List<_Place> _orderByDistance(List<_Place> places) {
    if (places.length < 2) {
      return List<_Place>.from(places);
    }

    final remaining = List<_Place>.from(places);
    final ordered = <_Place>[];

    // İlk olarak yüksek öncelikli mekânı seç.
    remaining.sort(
      (a, b) => _placePriority(b).compareTo(_placePriority(a)),
    );

    var current = remaining.removeAt(0);
    ordered.add(current);

    // Sonraki durakları mevcut durağa yakınlığa göre sırala.
    while (remaining.isNotEmpty) {
      remaining.sort(
        (a, b) => _distance(current, a).compareTo(
          _distance(current, b),
        ),
      );

      current = remaining.removeAt(0);
      ordered.add(current);
    }

    return ordered;
  }

  int _placePriority(_Place place) {
    switch (place.category) {
      case 'Şinto Mabedi':
      case 'Budist Tapınağı':
      case 'Kale':
      case 'Anıt':
      case 'Arkeolojik Alan':
      case 'Tarihî Yer':
      case 'Müze':
        return 5;

      case 'Bahçe':
      case 'Doğa Alanı':
      case 'Şelale':
      case 'Plaj':
      case 'Manzara':
      case 'Park':
        return 4;

      case 'Turistik Yer':
      case 'Eğlence':
      case 'Sanat Galerisi':
        return 3;

      default:
        return 1;
    }
  }

  double _distance(_Place a, _Place b) {
    return _filterService.distanceKm(
      latitude1: a.latitude,
      longitude1: a.longitude,
      latitude2: b.latitude,
      longitude2: b.longitude,
    );
  }

  double _average(List<double> values) {
    if (values.isEmpty) return 0;

    return values.reduce((a, b) => a + b) / values.length;
  }
}

// --------------------------------------------------------------
// MEKÂN MODELİ
// --------------------------------------------------------------

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