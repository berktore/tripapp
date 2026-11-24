import '../core/app_exception.dart';
import '../core/log.dart';
import '../models/destination_ref.dart';
import '../models/place.dart';
import '../models/trip_plan.dart';
import 'itinerary_distribution_service.dart';
import 'fallback_place_provider.dart';
import 'geoapify_place_provider.dart';
import 'nominatim_service.dart';
import 'opening_hours.dart';
import 'overpass_place_provider.dart';
import 'place_cache.dart';
import 'place_filter_service.dart';
import 'place_provider.dart';
import 'place_scoring_service.dart';
import 'wikipedia_place_provider.dart';

/// Gezi planının üretim hattı.
///
/// Akış: konum çözümleme -> (önbellek veya) gerçek mekân verisi ->
/// temizleme -> puanlama -> günlere dağıtma -> öğün/çalışma saati
/// düzeltmeleri -> [ItineraryDay] listesi.
class DestinationPlacesService {
  DestinationPlacesService({
    PlaceProvider? provider,
    NominatimService? nominatim,
    PlaceCache? cache,
    PlaceFilterService? filterService,
    PlaceScoringService? scoringService,
    ItineraryDistributionService? distributionService,
  }) : _provider =
           provider ??
           FallbackPlaceProvider(
             primary: GeoapifyPlaceProvider(),
             fallbacks: [OverpassPlaceProvider(), WikipediaPlaceProvider()],
           ),
       _nominatim = nominatim ?? NominatimService(),
       _cache = cache ?? PlaceCache(),
       _filterService = filterService ?? const PlaceFilterService(),
       _scoringService = scoringService ?? const PlaceScoringService(),
       _distributionService =
           distributionService ?? const ItineraryDistributionService();

  final PlaceProvider _provider;
  final NominatimService _nominatim;
  final PlaceCache _cache;
  final PlaceFilterService _filterService;
  final PlaceScoringService _scoringService;
  final ItineraryDistributionService _distributionService;

  static const List<String> _slotsWithFood = [
    '09:00',
    '11:00',
    '12:30',
    '15:00',
    '17:00',
  ];
  static const List<String> _attractionSlotsWithFood = [
    '09:00',
    '11:00',
    '15:00',
    '17:00',
  ];
  static const List<String> _attractionSlotsWithoutFood = [
    '09:00',
    '11:00',
    '13:30',
    '15:30',
    '17:00',
  ];
  static const String _nightlifeSlot = '21:00';

  Future<List<ItineraryDay>> buildItinerary({
    required DestinationRef destination,
    required int dayCount,
    required List<String> styles,
    required DateTime startDate,
    String budget = 'Orta',
  }) async {
    final cleanDestination = destination.name.trim();

    if (cleanDestination.isEmpty) {
      throw const AppException(
        'Destinasyon boş olamaz.',
        kind: AppErrorKind.invalidInput,
      );
    }

    if (dayCount < 1 || dayCount > 30) {
      throw const AppException(
        'Gezi süresi 1 ile 30 gün arasında olmalıdır.',
        kind: AppErrorKind.invalidInput,
      );
    }

    final resolved = await _nominatim.resolve(destination);
    final latitude = resolved.latitude;
    final longitude = resolved.longitude;

    if (latitude == null || longitude == null) {
      throw AppException(
        '"$cleanDestination" için koordinat bulunamadı.',
        kind: AppErrorKind.locationNotFound,
      );
    }

    final loaded = await _loadPlaces(latitude, longitude);

    if (loaded.places.isEmpty) {
      throw AppException(
        '$cleanDestination çevresinde kullanılabilir gezi noktası '
        'bulunamadı. Lütfen daha sonra tekrar dene.',
        kind: AppErrorKind.noPlaces,
      );
    }

    final uniquePlaces = _filterService.filter<Place>(
      places: loaded.places,
      getName: (place) => place.name,
      getId: (place) => place.osmId,
      getLatitude: (place) => place.latitude,
      getLongitude: (place) => place.longitude,
      getCategory: (place) => place.category,
    );

    final attractions = uniquePlaces.where((place) => !place.isFood).toList();

    if (attractions.isEmpty) {
      throw AppException(
        '$cleanDestination için turistik mekân verisi alınamadı. '
        'Harita veri servisi yanıt vermemiş veya sonuç döndürmemiş '
        'olabilir. Lütfen tekrar dene.',
        kind: AppErrorKind.noPlaces,
      );
    }

    logDebug(
      '${loaded.fromCache ? 'Önbellekten' : 'Ağdan'} '
      '${uniquePlaces.length} benzersiz mekân kullanılıyor.',
    );

    return _createDailyItinerary(
      destination: resolved,
      places: uniquePlaces,
      dayCount: dayCount,
      styles: styles,
      budget: budget,
      startDate: startDate,
    );
  }

  Future<({List<Place> places, bool fromCache})> _loadPlaces(
    double latitude,
    double longitude,
  ) async {
    final cached = await _cache.read(latitude: latitude, longitude: longitude);

    if (cached != null && cached.isNotEmpty) {
      return (places: cached, fromCache: true);
    }

    try {
      final fresh = await _provider.fetchPlaces(
        latitude: latitude,
        longitude: longitude,
      );

      if (fresh.isNotEmpty) {
        await _cache.write(
          latitude: latitude,
          longitude: longitude,
          places: fresh,
        );
      }

      return (places: fresh, fromCache: false);
    } on AppException {
      // Ağ başarısızsa süresi geçmiş önbellekle çalışmaya devam et.
      final stale = await _cache.read(
        latitude: latitude,
        longitude: longitude,
        allowStale: true,
      );

      if (stale != null && stale.isNotEmpty) {
        logDebug('Ağ hatası: süresi geçmiş önbellek kullanılıyor.');
        return (places: stale, fromCache: true);
      }

      rethrow;
    }
  }

  List<ItineraryDay> _createDailyItinerary({
    required DestinationRef destination,
    required List<Place> places,
    required int dayCount,
    required List<String> styles,
    required String budget,
    required DateTime startDate,
  }) {
    final wantsNightlife = styles.any(
      (style) => _normalizeCategory(style) == 'gece hayati',
    );
    final nightlife = places
        .where((place) => _isNightlife(place))
        .toList();
    final attractions = places
        .where(
          (place) =>
              !place.isFood && (!wantsNightlife || !_isNightlife(place)),
        )
        .toList();
    final foods = places.where((place) => place.isFood).toList();

    int scorePlace(Place place) {
      return _scoringService.score(
        category: place.category,
        tags: place.tags,
        styles: styles,
        budget: budget,
      );
    }

    final dailyPlaces = _distributionService.distribute<Place>(
      places: attractions,
      dayCount: dayCount,
      getLatitude: (place) => place.latitude,
      getLongitude: (place) => place.longitude,
      getScore: scorePlace,
      getCategory: (place) => place.category,
      maxPlacesPerDay: 4,
    );

    final foodByDay = _selectFoodForDays(
      dailyPlaces: dailyPlaces,
      foods: foods,
      startDate: startDate,
    );
    final nightlifeByDay = wantsNightlife
        ? _selectNightlifeForDays(
            dailyPlaces: dailyPlaces,
            nightlife: nightlife,
            startDate: startDate,
          )
        : List<Place?>.filled(dayCount, null);

    final days = <ItineraryDay>[];

    for (var day = 0; day < dayCount; day++) {
      final date = startDate.add(Duration(days: day));
      final dayPlaces = day < dailyPlaces.length ? dailyPlaces[day] : <Place>[];
      final food = day < foodByDay.length ? foodByDay[day] : null;
      final nightSpot = day < nightlifeByDay.length
          ? nightlifeByDay[day]
          : null;

      final ordered = _orderByDistance(dayPlaces);
      final attractionSlots = food == null
          ? _attractionSlotsWithoutFood
          : _attractionSlotsWithFood;
      _adjustForOpeningHours(ordered, date, attractionSlots);

      final slots = food == null ? _attractionSlotsWithoutFood : _slotsWithFood;
      final stops = <ItineraryStop>[];
      var attractionIndex = 0;

      for (var slotIndex = 0; slotIndex < slots.length; slotIndex++) {
        if (food != null && slotIndex == 2) {
          stops.add(_stopFrom(food, slots[slotIndex]));
          continue;
        }

        if (attractionIndex >= ordered.length) continue;

        stops.add(_stopFrom(ordered[attractionIndex], slots[slotIndex]));
        attractionIndex++;
      }

      if (nightSpot != null) {
        stops.add(_stopFrom(nightSpot, _nightlifeSlot));
      }

      days.add(
        ItineraryDay(
          dayNumber: day + 1,
          title: '${destination.name} · ${day + 1}. Gün',
          stops: stops,
        ),
      );
    }

    return days;
  }

  List<Place?> _selectFoodForDays({
    required List<List<Place>> dailyPlaces,
    required List<Place> foods,
    required DateTime startDate,
  }) {
    final foodByDay = List<Place?>.filled(dailyPlaces.length, null);
    final usedFoodIds = <String>{};

    for (var day = 0; day < dailyPlaces.length; day++) {
      final dayPlaces = dailyPlaces[day];
      if (dayPlaces.isEmpty) continue;

      final available = foods
          .where((place) => !usedFoodIds.contains(place.osmId))
          .toList();
      if (available.isEmpty) continue;

      final date = startDate.add(Duration(days: day));
      final lunch = _at(date, '12:30');
      final center = _centerOf(dayPlaces);

      available.sort((a, b) {
        final aOpen = _isOpen(a, lunch);
        final bOpen = _isOpen(b, lunch);
        if (aOpen != bOpen) return aOpen ? -1 : 1;

        final distanceA = _distanceTo(center, a);
        final distanceB = _distanceTo(center, b);
        return distanceA.compareTo(distanceB);
      });

      foodByDay[day] = available.first;
      usedFoodIds.add(available.first.osmId);
    }

    return foodByDay;
  }

  List<Place?> _selectNightlifeForDays({
    required List<List<Place>> dailyPlaces,
    required List<Place> nightlife,
    required DateTime startDate,
  }) {
    final nightlifeByDay = List<Place?>.filled(dailyPlaces.length, null);
    final usedIds = <String>{};

    for (var day = 0; day < dailyPlaces.length; day++) {
      final available = nightlife
          .where((place) => !usedIds.contains(place.osmId))
          .toList();
      if (available.isEmpty) break;

      final evening = _at(startDate.add(Duration(days: day)), _nightlifeSlot);
      final center = _centerOf(dailyPlaces[day]);
      available.sort((a, b) {
        final aOpen = _isOpen(a, evening);
        final bOpen = _isOpen(b, evening);
        if (aOpen != bOpen) return aOpen ? -1 : 1;

        return _distanceTo(center, a).compareTo(_distanceTo(center, b));
      });

      nightlifeByDay[day] = available.first;
      usedIds.add(available.first.osmId);
    }

    return nightlifeByDay;
  }

  ItineraryStop _stopFrom(Place place, String time) {
    return ItineraryStop(
      time: time,
      title: place.name,
      description: place.description,
      category: place.category,
      latitude: place.latitude,
      longitude: place.longitude,
      osmId: place.osmId,
      openingHours: place.openingHours,
      source: place.source,
      sourceUrl: place.sourceUrl,
    );
  }

  /// Rotayı bozmadan, kapalı görünen durakları aynı gün içinde
  /// açık olan başka bir durakla değiştirir.
  void _adjustForOpeningHours(
    List<Place> places,
    DateTime date,
    List<String> slots,
  ) {
    final limit = places.length < slots.length ? places.length : slots.length;

    for (var index = 0; index < limit; index++) {
      if (_isOpen(places[index], _at(date, slots[index]))) continue;

      for (var candidate = index + 1; candidate < limit; candidate++) {
        final currentOpensLater = _isOpen(
          places[index],
          _at(date, slots[candidate]),
        );
        final candidateOpensNow = _isOpen(
          places[candidate],
          _at(date, slots[index]),
        );

        if (currentOpensLater && candidateOpensNow) {
          final temporary = places[index];
          places[index] = places[candidate];
          places[candidate] = temporary;
          break;
        }
      }
    }
  }

  bool _isOpen(Place place, DateTime dateTime) {
    final hours = OpeningHours.parse(place.openingHours);
    if (hours == null) return true;
    return hours.isOpenAt(dateTime);
  }

  DateTime _at(DateTime date, String time) {
    final parts = time.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  (double, double) _centerOf(List<Place> places) {
    if (places.isEmpty) return (0, 0);

    final latitude =
        places.map((place) => place.latitude).reduce((a, b) => a + b) /
        places.length;
    final longitude =
        places.map((place) => place.longitude).reduce((a, b) => a + b) /
        places.length;

    return (latitude, longitude);
  }

  double _distanceTo((double, double) center, Place place) {
    return _filterService.distanceKm(
      latitude1: center.$1,
      longitude1: center.$2,
      latitude2: place.latitude,
      longitude2: place.longitude,
    );
  }

  List<Place> _orderByDistance(List<Place> places) {
    if (places.length < 2) return List<Place>.from(places);

    final remaining = List<Place>.from(places);
    final ordered = <Place>[];

    remaining.sort((a, b) => _placePriority(b).compareTo(_placePriority(a)));

    var current = remaining.removeAt(0);
    ordered.add(current);

    while (remaining.isNotEmpty) {
      remaining.sort(
        (a, b) => _distance(current, a).compareTo(_distance(current, b)),
      );

      current = remaining.removeAt(0);
      ordered.add(current);
    }

    return ordered;
  }

  int _placePriority(Place place) {
    switch (_normalizeCategory(place.category)) {
      case 'sinto mabedi':
      case 'budist tapinagi':
      case 'ibadethane':
      case 'kale':
      case 'anit':
      case 'arkeolojik alan':
      case 'tarihi yer':
      case 'tarihi alan':
      case 'tarihi kalinti':
      case 'mezar aniti':
      case 'muze':
      case 'saray':
        return 5;

      case 'bahce':
      case 'doga alani':
      case 'selale':
      case 'plaj':
      case 'manzara':
      case 'park':
        return 4;

      case 'turistik yer':
      case 'gezilecek yer':
      case 'eglence':
      case 'sanat galerisi':
      case 'kopru':
      case 'hamam':
      case 'pazar':
        return 3;

      default:
        return 1;
    }
  }

  bool _isNightlife(Place place) =>
      _normalizeCategory(place.category) == 'gece hayati';

  String _normalizeCategory(String value) {
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
        .replaceAll('û', 'u');
  }

  double _distance(Place a, Place b) {
    return _filterService.distanceKm(
      latitude1: a.latitude,
      longitude1: a.longitude,
      latitude2: b.latitude,
      longitude2: b.longitude,
    );
  }
}
