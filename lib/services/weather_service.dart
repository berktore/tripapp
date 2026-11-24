import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_exception.dart';
import '../core/log.dart';

class DailyWeather {
  const DailyWeather({
    required this.date,
    required this.code,
    required this.minTemperature,
    required this.maxTemperature,
    this.precipitationProbability,
  });

  final DateTime date;
  final int code;
  final double minTemperature;
  final double maxTemperature;
  final int? precipitationProbability;
}

class WeatherResult {
  const WeatherResult({required this.days, this.note});

  final List<DailyWeather> days;
  final String? note;

  bool get hasData => days.isNotEmpty;
}

/// Open-Meteo forecast API'si: ücretsiz, API anahtarı gerektirmez.
/// Ticari kullanım için Open-Meteo lisans/plan koşulları kontrol edilmelidir.
class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _cacheTtl = Duration(hours: 1);
  static const int _forecastHorizonDays = 16;
  static final Map<String, _WeatherCacheEntry> _cache = {};

  Future<WeatherResult> getForecast({
    required double latitude,
    required double longitude,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final lastForecastDate = todayDate.add(
      const Duration(days: _forecastHorizonDays - 1),
    );

    final rangeStart = _dateOnly(startDate).isAfter(todayDate)
        ? _dateOnly(startDate)
        : todayDate;
    final rangeEnd = _dateOnly(endDate).isBefore(lastForecastDate)
        ? _dateOnly(endDate)
        : lastForecastDate;

    if (rangeStart.isAfter(rangeEnd)) {
      return const WeatherResult(
        days: [],
        note:
            'Hava durumu tahmini yalnızca önümüzdeki 16 gün için '
            'kullanılabilir. Seyahat tarihin yaklaştığında tekrar kontrol et.',
      );
    }

    final cacheKey =
        '${latitude.toStringAsFixed(3)}:${longitude.toStringAsFixed(3)}:'
        '${_formatDate(rangeStart)}:${_formatDate(rangeEnd)}';

    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.createdAt) < _cacheTtl) {
      return cached.result;
    }

    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,'
          'precipitation_probability_max',
      'timezone': 'auto',
      'start_date': _formatDate(rangeStart),
      'end_date': _formatDate(rangeEnd),
    });

    try {
      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw AppException(
          'Hava durumu şu anda alınamıyor.',
          kind: AppErrorKind.providerUnavailable,
          details: 'Open-Meteo HTTP ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['daily'] is! Map) {
        throw const AppException(
          'Hava durumu yanıtı beklenen biçimde değil.',
          kind: AppErrorKind.providerUnavailable,
        );
      }

      final daily = Map<String, dynamic>.from(decoded['daily'] as Map);
      final times = daily['time'] as List<dynamic>? ?? [];
      final codes = daily['weather_code'] as List<dynamic>? ?? [];
      final maxTemps = daily['temperature_2m_max'] as List<dynamic>? ?? [];
      final minTemps = daily['temperature_2m_min'] as List<dynamic>? ?? [];
      final precipitation =
          daily['precipitation_probability_max'] as List<dynamic>? ?? [];

      final days = <DailyWeather>[];
      for (var index = 0; index < times.length; index++) {
        final parsedDate = DateTime.tryParse(times[index].toString());
        if (parsedDate == null) continue;
        if (index >= codes.length ||
            index >= maxTemps.length ||
            index >= minTemps.length) {
          continue;
        }

        days.add(
          DailyWeather(
            date: parsedDate,
            code: (codes[index] as num?)?.toInt() ?? 0,
            minTemperature: (minTemps[index] as num?)?.toDouble() ?? 0,
            maxTemperature: (maxTemps[index] as num?)?.toDouble() ?? 0,
            precipitationProbability: index < precipitation.length
                ? (precipitation[index] as num?)?.toInt()
                : null,
          ),
        );
      }

      final note = _dateOnly(endDate).isAfter(lastForecastDate)
          ? 'Tahmin 16 günle sınırlı; daha ileri tarihler için seyahate '
                'yakın tekrar kontrol edilecek.'
          : null;

      final result = WeatherResult(days: days, note: note);
      _cache[cacheKey] = _WeatherCacheEntry(
        result: result,
        createdAt: DateTime.now(),
      );
      return result;
    } on AppException {
      rethrow;
    } catch (error) {
      logDebug('Hava durumu isteği başarısız', error: error);
      throw AppException(
        'Hava durumu alınamadı. İnternet bağlantını kontrol edip '
        'tekrar deneyebilirsin.',
        kind: AppErrorKind.providerUnavailable,
        details: error.toString(),
      );
    }
  }

  static String descriptionForCode(int code) {
    if (code == 0) return 'Açık';
    if (code == 1) return 'Az bulutlu';
    if (code == 2) return 'Parçalı bulutlu';
    if (code == 3) return 'Kapalı';
    if (code == 45 || code == 48) return 'Sisli';
    if (code >= 51 && code <= 57) return 'Çisenti';
    if (code >= 61 && code <= 67) return 'Yağmurlu';
    if (code >= 71 && code <= 77) return 'Kar yağışlı';
    if (code >= 80 && code <= 82) return 'Sağanak yağış';
    if (code >= 85 && code <= 86) return 'Kar sağanağı';
    if (code >= 95) return 'Gök gürültülü fırtına';
    return 'Bilinmiyor';
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

class _WeatherCacheEntry {
  const _WeatherCacheEntry({required this.result, required this.createdAt});

  final WeatherResult result;
  final DateTime createdAt;
}
