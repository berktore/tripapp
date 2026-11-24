/// OpenStreetMap'ten gelen, doğrulanmış bir gezi noktası.
///
/// Uygulama içinde asla uydurma mekân üretilmez; bu model yalnızca
/// gerçek sağlayıcı yanıtlarından (OSM/Overpass, Wikipedia) doldurulur.
class Place {
  const Place({
    required this.name,
    required this.category,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.osmId,
    this.openingHours,
    this.tags = const {},
    this.source = 'OpenStreetMap',
    this.sourceUrl,
  });

  final String name;
  final String category;
  final String description;
  final double latitude;
  final double longitude;
  final String osmId;
  final String? openingHours;
  final Map<String, dynamic> tags;

  /// Verinin kaynağı: `OpenStreetMap` veya `Wikipedia`.
  /// Arayüzde atıf göstermek için kullanılır.
  final String source;

  /// Kaynak sayfanın adresi (atıf bağlantısı).
  final String? sourceUrl;

  bool get isFood => category == 'Restoran' || category == 'Kafe';

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'description': description,
    'latitude': latitude,
    'longitude': longitude,
    'osmId': osmId,
    'openingHours': openingHours,
    'tags': tags,
    'source': source,
    'sourceUrl': sourceUrl,
  };

  factory Place.fromJson(Map<String, dynamic> json) => Place(
    name: json['name']?.toString() ?? '',
    category: json['category']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    osmId: json['osmId']?.toString() ?? '',
    openingHours: json['openingHours']?.toString(),
    tags: json['tags'] is Map
        ? Map<String, dynamic>.from(json['tags'] as Map)
        : const {},
    source: json['source']?.toString() ?? 'OpenStreetMap',
    sourceUrl: json['sourceUrl']?.toString(),
  );
}
