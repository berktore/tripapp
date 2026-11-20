
class PlaceScoringService {
  const PlaceScoringService();

  int score({
    required String category,
    required Map<String, dynamic> tags,
    required List<String> styles,
    required String budget,
  }) {
    final normalizedCategory = _normalize(category);
    final normalizedTags = tags.map(
      (key, value) => MapEntry(key, _normalize(value.toString())),
    );

    var result = 0;

    // Temel turistik değer: Mekânın türüne göre başlangıç puanı.
    const baseScores = <String, int>{
      'tapinak': 14,
      'sinto mabedi': 14,
      'japon bahcesi': 13,
      'tarihi yer': 12,
      'kale': 12,
      'turistik yer': 11,
      'manzara': 10,
      'park': 9,
      'pazar': 9,
      'muze': 8,
      'eglence': 8,
      'alisveris': 6,
      'restoran': 5,
      'kafe': 3,
    };

    result += baseScores[normalizedCategory] ?? 5;

    // OSM etiketlerinden özel mekân türlerini tespit et.
    final tourism = normalizedTags['tourism'] ?? '';
    final historic = normalizedTags['historic'] ?? '';
    final amenity = normalizedTags['amenity'] ?? '';
    final religion = normalizedTags['religion'] ?? '';
    final building = normalizedTags['building'] ?? '';
    final leisure = normalizedTags['leisure'] ?? '';
    final shop = normalizedTags['shop'] ?? '';
    final natural = normalizedTags['natural'] ?? '';

    if (religion == 'buddhist' ||
        historic == 'temple' ||
        building == 'temple') {
      result += 12;
    }

    if (religion == 'shinto' ||
        amenity == 'place of worship' && religion == 'shinto') {
      result += 14;
    }

    if (leisure == 'garden' ||
        tourism == 'garden' ||
        leisure == 'nature reserve') {
      result += 10;
    }

    if (tourism == 'viewpoint') result += 8;
    if (historic == 'castle') result += 10;
    if (historic == 'monument') result += 7;
    if (amenity == 'marketplace') result += 8;
    if (shop == 'mall' || shop == 'department store') result += 4;
    if (natural == 'water' || natural == 'wood') result += 3;

    // Seyahat tarzına göre puanlama.
    for (final style in styles) {
      final normalizedStyle = _normalize(style);

      if (_matches(normalizedStyle, ['kultur', 'tarih'])) {
        if (_matches(normalizedCategory, [
          'muze',
          'tarihi',
          'tapinak',
          'sinto',
          'kale',
        ])) {
          result += 8;
        }
      }

      if (_matches(normalizedStyle, ['doga', 'macera'])) {
        if (_matches(normalizedCategory, [
          'bahce',
          'park',
          'selale',
          'manzara',
          'plaj',
          'dogal',
        ])) {
          result += 9;
        }
      }

      if (_matches(normalizedStyle, ['gastronomi', 'yemek'])) {
        if (normalizedCategory == 'restoran') result += 10;
        if (normalizedCategory == 'kafe') result += 5;
        if (normalizedCategory == 'pazar') result += 4;
      }

      if (_matches(normalizedStyle, ['alisveris'])) {
        if (normalizedCategory == 'pazar' ||
            normalizedCategory == 'alisveris' ||
            shop.isNotEmpty) {
          result += 8;
        }
      }

      if (_matches(normalizedStyle, ['gece hayati'])) {
        if (amenity == 'bar' ||
            amenity == 'pub' ||
            amenity == 'nightclub') {
          result += 10;
        }
      }

      if (_matches(normalizedStyle, ['dinlenme'])) {
        if (_matches(normalizedCategory, [
          'park',
          'bahce',
          'plaj',
          'manzara',
        ])) {
          result += 8;
        }
      }

      if (_matches(normalizedStyle, ['deniz'])) {
        if (natural == 'beach' || leisure == 'beach resort') {
          result += 10;
        }
      }
    }

    result += _budgetScore(normalizedCategory, budget);

    return result;
  }

  int _budgetScore(String category, String budget) {
    switch (_normalize(budget)) {
      case 'ekonomik':
        if (_matches(category, [
          'park',
          'bahce',
          'manzara',
          'tapinak',
          'sinto',
        ])) {
          return 4;
        }
        return 0;

      case 'konforlu':
        if (_matches(category, [
          'muze',
          'restoran',
          'japon bahcesi',
        ])) {
          return 3;
        }
        return 0;

      case 'luks':
        if (_matches(category, [
          'restoran',
          'alisveris',
          'eglence',
        ])) {
          return 4;
        }
        return 0;

      default:
        return 0;
    }
  }

  bool _matches(String value, List<String> terms) {
    return terms.any(value.contains);
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u');
  }
}
