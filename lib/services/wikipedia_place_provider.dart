import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_exception.dart';
import '../core/log.dart';
import '../models/place.dart';
import 'place_filter_service.dart';
import 'place_provider.dart';

/// Overpass yanıt vermediğinde devreye giren ücretsiz yedek sağlayıcı.
///
/// Wikipedia GeoSearch API'si anahtar gerektirmez, hızlıdır ve gerçek
/// yer adları/açıklamaları döndürür. Kategoriler Wikipedia metninden
/// yapılan anahtar kelime eşlemesiyle sınıflandırılır; mekân adı,
/// koordinat ve açıklama **hiçbir zaman** uydurulmaz.
///
/// Veri CC BY-SA lisanslıdır; arayüzde kaynak bağlantısı gösterilir.
class WikipediaPlaceProvider implements PlaceProvider {
  WikipediaPlaceProvider({
    http.Client? client,
    PlaceFilterService? filterService,
    List<String> languages = const ['tr', 'en'],
  }) : _client = client ?? http.Client(),
       _filterService = filterService ?? const PlaceFilterService(),
       // ignore: prefer_initializing_formals
       _languages = languages;
  final http.Client _client;
  final PlaceFilterService _filterService;
  final List<String> _languages;

  static const Duration _timeout = Duration(seconds: 12);
  static const int _radiusMeters = 10000;
  static const int _limit = 80;

  @override
  Future<List<Place>> fetchPlaces({
    required double latitude,
    required double longitude,
  }) async {
    for (final language in _languages) {
      try {
        final places = await _fetchForLanguage(language, latitude, longitude);
        if (places.isNotEmpty) {
          logDebug('Wikipedia ($language): ${places.length} mekân alındı.');
          return places;
        }
      } catch (error, stackTrace) {
        logDebug(
          'Wikipedia ($language) isteği başarısız',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return const [];
  }

  Future<List<Place>> _fetchForLanguage(
    String language,
    double centerLatitude,
    double centerLongitude,
  ) async {
    final searchUri = Uri.https('$language.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'list': 'geosearch',
      'gscoord': '$centerLatitude|$centerLongitude',
      'gsradius': '$_radiusMeters',
      'gslimit': '$_limit',
      'format': 'json',
      'origin': '*',
    });

    final searchResponse = await _client
        .get(searchUri, headers: {'Accept': 'application/json'})
        .timeout(_timeout);

    if (searchResponse.statusCode != 200) {
      throw AppException(
        'Wikipedia araması yanıt vermedi.',
        kind: AppErrorKind.providerUnavailable,
        details: 'HTTP ${searchResponse.statusCode}',
      );
    }

    final searchData = jsonDecode(searchResponse.body);
    if (searchData is! Map) return const [];

    final query = searchData['query'];
    final rawResults = query is Map ? query['geosearch'] : null;
    if (rawResults is! List) return const [];

    final pageIds = <String>[];
    final distances = <String, double>{};

    for (final item in rawResults.whereType<Map>()) {
      final pageId = item['pageid']?.toString();
      if (pageId == null || pageId.isEmpty) continue;

      pageIds.add(pageId);
      final distance = item['dist'];
      if (distance is num) distances[pageId] = distance.toDouble();

      // Tek istekte en fazla 50 sayfa ayrıntısı istenebilir.
      if (pageIds.length >= 50) break;
    }

    if (pageIds.isEmpty) return const [];

    final detailsUri = Uri.https('$language.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'pageids': pageIds.join('|'),
      'prop': 'extracts|coordinates|pageimages|pageprops|info',
      'exintro': '1',
      'explaintext': '1',
      'exsentences': '2',
      'piprop': 'thumbnail',
      'pithumbsize': '900',
      'ppprop': 'disambiguation',
      'inprop': 'url',
      'format': 'json',
      'origin': '*',
    });

    final detailsResponse = await _client
        .get(detailsUri, headers: {'Accept': 'application/json'})
        .timeout(_timeout);

    if (detailsResponse.statusCode != 200) {
      throw AppException(
        'Wikipedia ayrıntıları alınamadı.',
        kind: AppErrorKind.providerUnavailable,
        details: 'HTTP ${detailsResponse.statusCode}',
      );
    }

    final detailsData = jsonDecode(detailsResponse.body);
    if (detailsData is! Map) return const [];

    final detailsQuery = detailsData['query'];
    final pages = detailsQuery is Map ? detailsQuery['pages'] : null;
    if (pages is! Map) return const [];

    final places = <Place>[];

    for (final entry in pages.entries) {
      final page = entry.value;
      if (page is! Map) continue;

      final pageProps = page['pageprops'];
      if (pageProps is Map && pageProps.containsKey('disambiguation')) {
        continue;
      }

      final title = page['title']?.toString().trim() ?? '';
      if (title.isEmpty) continue;

      final coordinates = page['coordinates'];
      if (coordinates is! List || coordinates.isEmpty) continue;

      final coordinate = coordinates.first;
      if (coordinate is! Map) continue;

      final latitudeValue = coordinate['lat'];
      final longitudeValue = coordinate['lon'];
      if (latitudeValue is! num || longitudeValue is! num) continue;

      final placeLatitude = latitudeValue.toDouble();
      final placeLongitude = longitudeValue.toDouble();
      if (!_isValidCoordinate(placeLatitude, placeLongitude)) continue;

      final distance = _filterService.distanceKm(
        latitude1: centerLatitude,
        longitude1: centerLongitude,
        latitude2: placeLatitude,
        longitude2: placeLongitude,
      );
      if (distance > 25) continue;

      final extract = page['extract']?.toString().trim() ?? '';
      final category = _categoryFromText('$title ${_firstSentence(extract)}');
      final pageId = page['pageid']?.toString() ?? entry.key.toString();

      places.add(
        Place(
          name: title,
          category: category,
          description: extract.isEmpty
              ? _defaultDescription(category)
              : _cleanExtract(extract),
          latitude: placeLatitude,
          longitude: placeLongitude,
          osmId: 'wikipedia:$language:$pageId',
          tags: {'wikipedia': '$language:$pageId'},
          source: 'Wikipedia',
          sourceUrl:
              page['fullurl']?.toString() ??
              'https://$language.wikipedia.org/?curid=$pageId',
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

  /// Wikipedia başlığından ve özetin ilk cümlesinden kategori çıkarır.
  ///
  /// Yalnızca başlık ve ilk cümle kullanılır: uzun özette geçen alakasız
  /// bir kelime (ör. bir caminin sayfasında geçen "kale") yanlış
  /// sınıflandırmaya yol açmasın. Bu bir etiketlemedir; mekân hakkında
  /// yeni bilgi üretmez.
  String _categoryFromText(String text) {
    final value = _normalize(text);
    final tokens = value
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toSet();

    const rules = <String, List<String>>{
      'Müze': ['muze', 'museum'],
      'İbadethane': [
        'cami',
        'camii',
        'mosque',
        'kilise',
        'church',
        'tapinak',
        'temple',
        'sinagog',
        'synagogue',
        'manastir',
        'monastery',
      ],
      'Kale': ['kale', 'kalesi', 'hisar', 'castle', 'fortress'],
      'Park': ['park', 'parki'],
      'Bahçe': ['bahce', 'garden'],
      'Plaj': ['plaj', 'beach', 'sahil'],
      'Şelale': ['selale', 'waterfall'],
      'Pazar': ['pazar', 'carsi', 'market', 'bazaar'],
      'Manzara': ['manzara', 'seyir', 'viewpoint'],
      'Anıt': ['anit', 'monument', 'memorial', 'dikilitas', 'obelisk'],
      'Arkeolojik Alan': [
        'arkeolojik',
        'archaeological',
        'antik kent',
        'oren yeri',
        'ruins',
      ],
      'Saray': ['saray', 'palace'],
      'Köprü': ['kopru', 'bridge'],
      'Hamam': ['hamam', 'bath'],
    };

    for (final rule in rules.entries) {
      for (final keyword in rule.value) {
        final matched = keyword.contains(' ')
            ? value.contains(keyword)
            : _tokensMatch(tokens, keyword);

        if (matched) return rule.key;
      }
    }

    return 'Gezilecek Yer';
  }

  /// Kelime bazlı eşleşme: "Köprülü Kütüphanesi" metni "köprü" sayılmaz.
  ///
  /// Türkçe iyelik ekleri (`saray`/`sarayı`, `kale`/`kalesi`,
  /// `tapınak`/`tapınağı`) kabul edilir.
  bool _tokensMatch(Set<String> tokens, String keyword) {
    if (tokens.contains(keyword)) return true;

    for (final suffix in const [
      'i',
      'si',
      'gi',
      'u',
      'su',
      'gu',
      'in',
      'nin',
    ]) {
      if (tokens.contains('$keyword$suffix')) return true;
    }

    return false;
  }

  String _firstSentence(String extract) {
    if (extract.isEmpty) return '';

    final normalized = extract.replaceAll(RegExp(r'\s+'), ' ').trim();
    final end = normalized.indexOf('. ');
    final sentence = end == -1 ? normalized : normalized.substring(0, end);

    return sentence.length <= 160 ? sentence : sentence.substring(0, 160);
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _cleanExtract(String extract) {
    final normalized = extract.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 320) return normalized;

    final cut = normalized.substring(0, 320);
    final lastPeriod = cut.lastIndexOf('. ');
    if (lastPeriod > 120) return cut.substring(0, lastPeriod + 1);

    return '${cut.trimRight()}…';
  }

  String _defaultDescription(String category) {
    if (category == 'Gezilecek Yer') {
      return 'Bölgede bulunan, ziyaret edilebilecek gerçek bir nokta.';
    }
    return 'Bölgede bulunan bir $category.';
  }
}
