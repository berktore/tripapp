import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_exception.dart';
import '../core/log.dart';
import '../models/destination_ref.dart';

/// Nominatim ile konum çözen servis.
///
/// Arama sonuçlarından gelen koordinatlar varsa hiç istek atılmaz; bu hem
/// Türkçe egzonim sorununu (Londra/Venedik/Münih) hem de gereksiz isteği
/// ortadan kaldırır.
class NominatimService {
  NominatimService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const String _userAgent = 'TripApp/1.0';

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

  /// Türkçe egzonimler için yerel/İngilizce karşılıklar.
  static const Map<String, String> _aliases = {
    'londra': 'London',
    'venedik': 'Venezia',
    'munih': 'München',
    'pekın': 'Beijing',
    'pekin': 'Beijing',
    'atina': 'Athens',
    'kopenhag': 'Copenhagen',
    'varsova': 'Warszawa',
    'bukres': 'Bucuresti',
    'sofya': 'Sofia',
    'belgrad': 'Beograd',
    'saraybosna': 'Sarajevo',
    'tiflis': 'Tbilisi',
    'kahire': 'Cairo',
    'kudus': 'Jerusalem',
    'sankt peterburg': 'Saint Petersburg',
    'new york': 'New York',
    'los angeles': 'Los Angeles',
    'san francisco': 'San Francisco',
    'las vegas': 'Las Vegas',
    'miami': 'Miami',
    'chicago': 'Chicago',
    'toronto': 'Toronto',
    'vancouver': 'Vancouver',
    'marakes': 'Marrakech',
    'marakeş': 'Marrakech',
  };

  Future<DestinationRef> resolve(DestinationRef destination) async {
    final name = destination.name.trim();
    if (name.isEmpty) {
      throw const AppException(
        'Lütfen bir destinasyon seç.',
        kind: AppErrorKind.invalidInput,
      );
    }

    if (destination.hasCoordinates) {
      return destination;
    }

    final canonical = _aliases[_normalize(name)] ?? name;
    final countryName =
        destination.country?.trim() ??
        _countryNames[destination.countryCode?.toLowerCase()];

    final parameters = <String, String>{
      'q': countryName == null ? canonical : '$canonical, $countryName',
      'format': 'jsonv2',
      'limit': '10',
      'addressdetails': '1',
      'accept-language': 'tr',
    };

    final countryCode = destination.countryCode?.toLowerCase();
    if (countryCode != null && countryCode.isNotEmpty) {
      parameters['countrycodes'] = countryCode;
    }

    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      parameters,
    );

    http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: {
              'User-Agent': _userAgent,
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));
    } catch (error) {
      logDebug('Nominatim isteği başarısız', error: error);
      throw AppException(
        'Konum servisine ulaşılamadı. İnternet bağlantını kontrol edip '
        'tekrar dene.',
        kind: AppErrorKind.providerUnavailable,
        details: error.toString(),
      );
    }

    if (response.statusCode != 200) {
      throw AppException(
        'Konum servisi yanıt vermedi.',
        kind: AppErrorKind.providerUnavailable,
        details: 'Nominatim HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const AppException(
        'Konum servisinden geçersiz veri geldi.',
        kind: AppErrorKind.providerUnavailable,
      );
    }

    final candidates = <_Candidate>[];

    for (final item in decoded.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      final latitude = double.tryParse(map['lat']?.toString() ?? '');
      final longitude = double.tryParse(map['lon']?.toString() ?? '');
      final address = map['address'];

      if (latitude == null || longitude == null) continue;
      if (!_isValidCoordinate(latitude, longitude)) continue;

      String? actualCountryCode;
      String? actualCountry;
      if (address is Map) {
        actualCountryCode = address['country_code']?.toString().toLowerCase();
        actualCountry = address['country']?.toString();
      }

      if (countryCode != null &&
          countryCode.isNotEmpty &&
          actualCountryCode != null &&
          actualCountryCode != countryCode) {
        continue;
      }

      final displayName = map['display_name']?.toString() ?? '';
      final importance = double.tryParse(
            map['importance']?.toString() ?? '',
          ) ??
          0;

      candidates.add(
        _Candidate(
          latitude: latitude,
          longitude: longitude,
          countryCode: actualCountryCode,
          country: actualCountry,
          displayName: displayName,
          type: map['type']?.toString(),
          importance: importance,
        ),
      );
    }

    if (candidates.isEmpty) {
      throw AppException(
        '"$name" için konum bulunamadı. Şehir adını kontrol edip '
        'arama sonuçlarından birini seçmeyi dene.',
        kind: AppErrorKind.locationNotFound,
      );
    }

    final normalizedQuery = _normalize(canonical);
    candidates.sort(
      (a, b) => _score(b, normalizedQuery).compareTo(
        _score(a, normalizedQuery),
      ),
    );

    final best = candidates.first;
    return DestinationRef(
      name: name,
      country: best.country ?? countryName,
      countryCode: best.countryCode ?? countryCode,
      latitude: best.latitude,
      longitude: best.longitude,
    );
  }

  int _score(_Candidate candidate, String normalizedQuery) {
    var score = (candidate.importance * 10).round().clamp(0, 10).toInt();

    const cityTypes = {
      'city',
      'town',
      'village',
      'municipality',
      'administrative',
      'county',
    };
    if (cityTypes.contains(candidate.type)) score += 8;

    final displayName = _normalize(candidate.displayName);
    if (displayName.startsWith(normalizedQuery)) score += 6;

    final tokens = normalizedQuery
        .split(' ')
        .where((token) => token.length > 2)
        .toList();

    for (final token in tokens) {
      if (displayName.contains(token)) score += 4;
    }

    return score;
  }

  bool _isValidCoordinate(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

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
}

class _Candidate {
  const _Candidate({
    required this.latitude,
    required this.longitude,
    required this.displayName,
    required this.importance,
    this.countryCode,
    this.country,
    this.type,
  });

  final double latitude;
  final double longitude;
  final String displayName;
  final double importance;
  final String? countryCode;
  final String? country;
  final String? type;
}
