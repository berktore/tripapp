/// Kullanıcının seçtiği destinasyon.
///
/// Arama sonuçlarından seçildiğinde koordinat ve ülke bilgisi de taşınır.
/// Böylece aynı isimli şehirler (ör. Paris/Texas) ve Türkçe egzonimler
/// (Londra, Venedik, Münih) için tekrar coğrafi arama yapmak gerekmez.
class DestinationRef {
  const DestinationRef({
    required this.name,
    this.country,
    this.countryCode,
    this.latitude,
    this.longitude,
  });

  final String name;
  final String? country;
  final String? countryCode;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates {
    final lat = latitude;
    final lon = longitude;
    return lat != null &&
        lon != null &&
        lat.isFinite &&
        lon.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lon >= -180 &&
        lon <= 180;
  }

  DestinationRef copyWith({
    String? name,
    String? country,
    String? countryCode,
    double? latitude,
    double? longitude,
  }) {
    return DestinationRef(
      name: name ?? this.name,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
