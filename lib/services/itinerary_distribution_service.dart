import 'dart:math' as math;

import 'place_filter_service.dart';

/// Mekânları puan, kategori çeşitliliği ve coğrafi yakınlığa
/// göre günlere dağıtır.
class ItineraryDistributionService {
  const ItineraryDistributionService();

  List<List<T>> distribute<T>({
    required List<T> places,
    required int dayCount,
    required double Function(T place) getLatitude,
    required double Function(T place) getLongitude,
    required int Function(T place) getScore,
    required String Function(T place) getCategory,
    int maxPlacesPerDay = 4,
  }) {
    if (dayCount <= 0 || maxPlacesPerDay <= 0) {
      return [];
    }

    final days = List.generate(dayCount, (_) => <T>[]);

    if (places.isEmpty) return days;

    final candidates = List<T>.of(places)
      ..sort((a, b) => getScore(b).compareTo(getScore(a)));

    final capacity = dayCount * maxPlacesPerDay;

    // Önce yüksek puanlı ama kategori bakımından çeşitli
    // bir aday havuzu oluştur.
    final selected = <T>[];
    final pool = List<T>.of(candidates);
    final selectedCategoryCounts = <String, int>{};

    while (selected.length < capacity && pool.isNotEmpty) {
      T? best;
      var bestValue = double.negativeInfinity;

      for (final candidate in pool) {
        final category = _normalizeCategory(getCategory(candidate));
        final repeatedCount = selectedCategoryCounts[category] ?? 0;

        final value = getScore(candidate) - repeatedCount * 7.0;

        if (value > bestValue) {
          bestValue = value;
          best = candidate;
        }
      }

      if (best == null) break;

      selected.add(best);
      pool.remove(best);

      final category = _normalizeCategory(getCategory(best));
      selectedCategoryCounts[category] =
          (selectedCategoryCounts[category] ?? 0) + 1;
    }

    if (selected.isEmpty) return days;

    // İlk günün başlangıç noktası en yüksek puanlı mekândır.
    final remaining = List<T>.of(selected);
    final seeds = <T>[remaining.removeAt(0)];

    // Diğer günlere coğrafi olarak farklı başlangıç noktaları seç.
    while (seeds.length < dayCount && remaining.isNotEmpty) {
      T? bestCandidate;
      var bestValue = double.negativeInfinity;

      for (final candidate in remaining) {
        var nearestDistance = double.infinity;

        for (final seed in seeds) {
          final distance = _distance(
            getLatitude(candidate),
            getLongitude(candidate),
            getLatitude(seed),
            getLongitude(seed),
          );

          nearestDistance = math.min(nearestDistance, distance);
        }

        final value = nearestDistance + getScore(candidate) * 0.01;

        if (value > bestValue) {
          bestValue = value;
          bestCandidate = candidate;
        }
      }

      if (bestCandidate == null) break;

      seeds.add(bestCandidate);
      remaining.remove(bestCandidate);
    }

    for (var i = 0; i < seeds.length; i++) {
      days[i].add(seeds[i]);
    }

    remaining.sort((a, b) => getScore(b).compareTo(getScore(a)));

    // Kalan mekânları yakınlık ve kategori çeşitliliğiyle dağıt.
    for (final place in remaining) {
      var bestDayIndex = -1;
      var bestDayValue = double.infinity;

      for (var dayIndex = 0; dayIndex < days.length; dayIndex++) {
        final day = days[dayIndex];

        if (day.length >= maxPlacesPerDay) continue;

        final centerLatitude = _average(
          day.map(getLatitude).toList(),
        );

        final centerLongitude = _average(
          day.map(getLongitude).toList(),
        );

        final distance = _distance(
          getLatitude(place),
          getLongitude(place),
          centerLatitude,
          centerLongitude,
        );

        final categoryPenalty = _categoryPenalty(
          getCategory(place),
          day.map(getCategory).toList(),
        );

        // Mesafe kilometre cinsinden, kategori cezası da
        // kilometre karşılığı bir tercih ağırlığıdır.
        final dayValue = distance + categoryPenalty;

        if (dayValue < bestDayValue) {
          bestDayValue = dayValue;
          bestDayIndex = dayIndex;
        }
      }

      if (bestDayIndex >= 0) {
        days[bestDayIndex].add(place);
      }
    }

    return days;
  }

  /// Aynı kategoriden birden fazla mekânı aynı güne eklemeyi
  /// zorlaştırır. Alternatif yoksa tekrarına izin verir.
  double _categoryPenalty(
    String category,
    List<String> dayCategories,
  ) {
    final normalized = _normalizeCategory(category);

    final sameCategoryCount = dayCategories
        .where((item) => _normalizeCategory(item) == normalized)
        .length;

    if (sameCategoryCount == 0) return 0;

    return sameCategoryCount * 5.0;
  }

  String _normalizeCategory(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
  }

  double _average(List<double> values) {
    if (values.isEmpty) return 0;

    return values.reduce((a, b) => a + b) / values.length;
  }

  double _distance(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    const distanceService = PlaceFilterService();

    return distanceService.distanceKm(
      latitude1: latitude1,
      longitude1: longitude1,
      latitude2: latitude2,
      longitude2: longitude2,
    );
  }
}