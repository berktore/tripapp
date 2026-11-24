import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_exception.dart';
import '../core/log.dart';
import '../models/place.dart';
import 'place_filter_service.dart';
import 'place_provider.dart';

/// OpenStreetMap Overpass API üzerinden mekân arayan sağlayıcı.
///
/// Tasarım kararları:
/// - **Tek istek:** Tüm kategoriler tek Overpass sorgusunda toplanır.
///   Overpass kullanım politikası paralel sorguları önermez; tek istek
///   hem daha hızlı hem de sunucuya karşı daha naziktir.
/// - **Sıralı yedek sunucu:** İlk sunucu yanıt vermezse sıradaki denenir.
/// - **Toplam süre sınırı:** [_totalTimeout] aşılırsa anlaşılır bir hata
///   fırlatılır; arayüz sonsuza kadar beklemez.
/// - Sonuçlar [PlaceCache] tarafından 72 saat önbelleklenir.
class OverpassPlaceProvider implements PlaceProvider {
  OverpassPlaceProvider({
    http.Client? client,
    PlaceFilterService? filterService,
  }) : _client = client ?? http.Client(),
       _filterService = filterService ?? const PlaceFilterService();

  final http.Client _client;
  final PlaceFilterService _filterService;

  // Not: Yayın öncesi UA'ya gerçek iletişim adresi eklenmeli
  // (OSM kullanım politikası gereği).
  static const String _userAgent = 'TripApp/1.0';

  static const List<String> _servers = [
    'overpass-api.de',
    'overpass.kumi.systems',
    'overpass.private.coffee',
  ];

  /// Turistik mekânlar için yarıçap. Şehir merkezinden 6 km, çoğu
  /// destinasyonda gezilecek noktaların tamamını kapsar.
  static const int _attractionRadiusMeters = 6000;

  /// Yeme-içme ve gece hayatı için daha dar yarıçap; yürüme mesafesindeki seçenekler
  /// yeterlidir ve yanıt süresini kısaltır.
  static const int _foodRadiusMeters = 3000;

  /// Sunucu başına istek süresi. Süre bittiğinde diğer yedek sunucu
  /// gecikmeden denenir.
  static const Duration _requestTimeout = Duration(seconds: 18);

  /// Tüm denemeler için toplam süre.
  static const Duration _totalTimeout = Duration(seconds: 55);

  static const double _maxDistanceKm = 25;

  @override
  Future<List<Place>> fetchPlaces({
    required double latitude,
    required double longitude,
  }) async {
    final query = _buildQuery(latitude, longitude);
    final deadline = DateTime.now().add(_totalTimeout);

    var anyServerReached = false;

    for (final server in _servers) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;

      final attemptTimeout = remaining < _requestTimeout
          ? remaining
          : _requestTimeout;

      try {
        final response = await _client
            .post(
              Uri.https(server, '/api/interpreter'),
              body: {'data': query},
              headers: {
                'User-Agent': _userAgent,
                'Accept': 'application/json',
              },
            )
            .timeout(attemptTimeout);

        if (response.statusCode != 200) {
          logDebug(
            'Overpass $server: HTTP ${response.statusCode}',
            error: response.reasonPhrase,
          );
          continue;
        }

        anyServerReached = true;

        final places = _parseResponse(response.body, latitude, longitude);

        if (places.isNotEmpty) {
          logDebug('Overpass ($server): ${places.length} mekân alındı.');
          return places;
        }

        logDebug('Overpass ($server): yanıt boş.');
      } on TimeoutException {
        logDebug('Overpass $server: zaman aşımı.');
      } catch (error, stackTrace) {
        logDebug(
          'Overpass $server isteği başarısız',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    if (!anyServerReached) {
      throw const AppException(
        'Mekân verisi sunucularına ulaşılamadı. İnternet bağlantını '
        'kontrol edip tekrar dene.',
        kind: AppErrorKind.providerUnavailable,
        details: 'Tüm Overpass sunucuları başarısız oldu.',
      );
    }

    return const [];
  }

  /// Tüm kategorileri tek Overpass QL sorgusunda birleştirir.
  String _buildQuery(double latitude, double longitude) {
    final attractions = '(around:$_attractionRadiusMeters,$latitude,$longitude)';
    final food = '(around:$_foodRadiusMeters,$latitude,$longitude)';

    return '''
[out:json][timeout:15];
(
  node$attractions["tourism"~"attraction|museum|viewpoint|zoo|aquarium|artwork|gallery|theme_park"];
  way$attractions["tourism"~"attraction|museum|viewpoint|zoo|aquarium|artwork|gallery|theme_park"];
  node$attractions["amenity"="place_of_worship"];
  way$attractions["amenity"="place_of_worship"];
  node$attractions["historic"~"castle|monument|memorial|archaeological_site|ruins|tomb|fort|city_gate|palace"];
  way$attractions["historic"~"castle|monument|memorial|archaeological_site|ruins|tomb|fort|city_gate|palace"];
  node$attractions["leisure"~"park|garden|nature_reserve"];
  way$attractions["leisure"~"park|garden|nature_reserve"];
  node$attractions["amenity"="marketplace"];
  way$attractions["amenity"="marketplace"];
  node$attractions["shop"~"mall|department_store|marketplace"];
  way$attractions["shop"~"mall|department_store|marketplace"];
  node$attractions["natural"="beach"];
  way$attractions["natural"="beach"];
  node$attractions["waterway"="waterfall"];
  way$attractions["waterway"="waterfall"];
  node$food["amenity"~"restaurant|cafe|food_court|bar|pub|nightclub"];
  way$food["amenity"~"restaurant|cafe|food_court|bar|pub|nightclub"];
  node$food["shop"="bakery"];
  way$food["shop"="bakery"];
);
out center tags 250;
''';
  }

  List<Place> _parseResponse(
    String body,
    double centerLatitude,
    double centerLongitude,
  ) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      logDebug('Overpass: JSON nesnesi bekleniyordu.');
      return const [];
    }

    final rawElements = decoded['elements'];
    if (rawElements is! List) {
      logDebug('Overpass: elements bulunamadı.');
      return const [];
    }

    return _parseElements(rawElements, centerLatitude, centerLongitude);
  }

  List<Place> _parseElements(
    List<dynamic> elements,
    double centerLatitude,
    double centerLongitude,
  ) {
    final places = <Place>[];

    for (final element in elements) {
      if (element is! Map) continue;

      final map = Map<String, dynamic>.from(element);
      final rawTags = map['tags'];
      final tags = rawTags is Map
          ? Map<String, dynamic>.from(rawTags)
          : <String, dynamic>{};

      final name = _readableName(tags);
      if (name.isEmpty) continue;

      final rawCenter = map['center'];
      final center = rawCenter is Map
          ? Map<String, dynamic>.from(rawCenter)
          : null;
      final rawLatitude = map['lat'] ?? center?['lat'];
      final rawLongitude = map['lon'] ?? center?['lon'];

      if (rawLatitude is! num || rawLongitude is! num) continue;

      final latitude = rawLatitude.toDouble();
      final longitude = rawLongitude.toDouble();
      if (!_isValidCoordinate(latitude, longitude)) continue;

      final distance = _filterService.distanceKm(
        latitude1: centerLatitude,
        longitude1: centerLongitude,
        latitude2: latitude,
        longitude2: longitude,
      );
      if (distance > _maxDistanceKm) continue;

      final category = _category(tags);
      if (category == null) continue;

      places.add(
        Place(
          name: name,
          category: category,
          description: _description(category, tags),
          latitude: latitude,
          longitude: longitude,
          osmId: '${map['type']}/${map['id']}',
          openingHours: tags['opening_hours']?.toString(),
          tags: tags,
          source: 'OpenStreetMap',
          sourceUrl:
              'https://www.openstreetmap.org/${map['type']}/${map['id']}',
        ),
      );
    }

    return places;
  }

  bool _isValidCoordinate(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  String _readableName(Map<String, dynamic> tags) {
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

  String? _category(Map<String, dynamic> tags) {
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
    if (historic == 'monument' || historic == 'memorial') return 'Anıt';
    if (historic == 'archaeological_site') return 'Arkeolojik Alan';
    if (historic == 'ruins') return 'Tarihî Kalıntı';
    if (historic == 'tomb') return 'Mezar Anıtı';

    if (leisure == 'garden' || tourism == 'garden') return 'Bahçe';
    if (leisure == 'nature_reserve') return 'Doğa Alanı';
    if (leisure == 'park') return 'Park';

    if (tourism == 'museum') return 'Müze';
    if (tourism == 'viewpoint') return 'Manzara';
    if (tourism == 'zoo' || tourism == 'aquarium') return 'Eğlence';
    if (tourism == 'gallery') return 'Sanat Galerisi';
    if (tourism == 'attraction' || tourism == 'artwork') return 'Turistik Yer';

    if (amenity == 'marketplace' || shop == 'marketplace') return 'Pazar';
    if (shop == 'mall' || shop == 'department_store') return 'Alışveriş';

    if (waterway == 'waterfall' || natural == 'waterfall') return 'Şelale';
    if (natural == 'beach') return 'Plaj';

    if (amenity == 'bar' || amenity == 'pub' || amenity == 'nightclub') {
      return 'Gece Hayatı';
    }
    if (amenity == 'restaurant' || amenity == 'food_court') return 'Restoran';
    if (amenity == 'cafe' || shop == 'bakery') return 'Kafe';

    if (historic != null) return 'Tarihî Yer';

    return null;
  }

  String _description(String category, Map<String, dynamic> tags) {
    final turkishDescription = tags['description:tr']?.toString().trim();
    if (turkishDescription != null && turkishDescription.isNotEmpty) {
      return turkishDescription;
    }

    const descriptions = <String, String>{
      'Şinto Mabedi':
          'Japon Şinto inancına ait geleneksel bir ibadet alanı.',
      'Budist Tapınağı':
          'Budist mimarisini ve Japon kültürünü keşfedebileceğin bir tapınak.',
      'İbadethane': 'Bölgenin inanç ve kültür mirasının bir parçası.',
      'Kale': 'Bölgenin savunma tarihini yansıtan tarihî bir yapı.',
      'Anıt': 'Tarihî bir olayı veya kişiyi anmak için yapılmış bir eser.',
      'Arkeolojik Alan':
          'Geçmiş uygarlıklardan izler taşıyan arkeolojik bir alan.',
      'Tarihî Kalıntı':
          'Geçmiş dönemlerden günümüze ulaşan tarihî kalıntılar.',
      'Mezar Anıtı': 'Tarihî ve kültürel öneme sahip bir anıt mezar.',
      'Tarihî Yer':
          'Bölgenin tarihî mirasını yansıtan bir ziyaret noktası.',
      'Bahçe':
          'Peyzaj düzenlemesi ve doğal güzelliğiyle öne çıkan bir bahçe.',
      'Park':
          'Açık havada dinlenmek ve doğayla vakit geçirmek için bir alan.',
      'Doğa Alanı': 'Doğal yaşamı ve çevreyi keşfedebileceğin bir alan.',
      'Müze':
          'Sanat, kültür veya tarih koleksiyonlarını keşfedebileceğin bir müze.',
      'Manzara': 'Çevreyi izlemek ve fotoğraf çekmek için bir seyir noktası.',
      'Eğlence': 'Keyifli vakit geçirmek için ziyaret edilebilecek bir yer.',
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
      'Plaj': 'Deniz ve sahil keyfi için ziyaret edilebilecek bir alan.',
      'Gece Hayatı':
          'Akşamı değerlendirmek için tercih edilebilecek bir eğlence mekânı.',
      'Restoran':
          'Gezi sırasında yemek molası verebileceğin bir restoran.',
      'Kafe': 'Dinlenmek ve mola vermek için uğrayabileceğin bir kafe.',
    };

    return descriptions[category] ?? 'Ziyaret edilebilecek bir nokta.';
  }
}
