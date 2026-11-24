import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/trip_plan.dart';
import '../services/trip_storage.dart';
import '../theme/app_theme.dart';

class AntalyaMapScreen extends StatefulWidget {
  const AntalyaMapScreen({super.key});

  @override
  State<AntalyaMapScreen> createState() => _AntalyaMapScreenState();
}

class _AntalyaPlace {
  final String name;
  final String description;
  final String category;
  final String time;
  final LatLng location;

  const _AntalyaPlace({
    required this.name,
    required this.description,
    required this.category,
    required this.time,
    required this.location,
  });
}

class _AntalyaMapScreenState extends State<AntalyaMapScreen> {
  static const LatLng _antalyaCenter = LatLng(36.8841, 30.7056);

  static const List<_AntalyaPlace> _places = [
    _AntalyaPlace(
      name: 'Kaleiçi',
      description: 'Tarihi sokakları, marina çevresi ve Osmanlı dönemi evleriyle eski Antalya.',
      category: 'Tarihi bölge',
      time: '10:00',
      location: LatLng(36.8850, 30.7070),
    ),
    _AntalyaPlace(
      name: 'Hadrian Kapısı',
      description:
          'Roma İmparatoru Hadrianus onuruna yapılmış tarihi anıt kapı.',
      category: 'Tarihi yapı',
      time: '11:00',
      location: LatLng(36.8853, 30.7078),
    ),
    _AntalyaPlace(
      name: 'Yivli Minare',
      description:
          'Antalya şehir merkezinin simgelerinden Selçuklu dönemi eseri.',
      category: 'Tarihi yapı',
      time: '12:00',
      location: LatLng(36.8870, 30.7050),
    ),
    _AntalyaPlace(
      name: 'Antalya Müzesi',
      description: 'Bölgenin arkeolojik mirasını ve tarihini keşfet.',
      category: 'Müze',
      time: '14:00',
      location: LatLng(36.8870, 30.6730),
    ),
    _AntalyaPlace(
      name: 'Konyaaltı Plajı',
      description:
          'Toros Dağları manzaralı uzun Akdeniz sahilinde vakit geçir.',
      category: 'Plaj',
      time: '16:00',
      location: LatLng(36.8650, 30.6360),
    ),
    _AntalyaPlace(
      name: 'Aşağı Düden Şelalesi',
      description: 'Şelalenin falezlerden Akdeniz’e döküldüğü seyir alanı.',
      category: 'Doğa',
      time: '17:30',
      location: LatLng(36.8500, 30.7850),
    ),
    _AntalyaPlace(
      name: 'Aspendos Antik Tiyatrosu',
      description: 'Roma döneminden günümüze ulaşan etkileyici antik tiyatro.',
      category: 'Antik kent',
      time: '09:30',
      location: LatLng(36.9370, 31.1730),
    ),
  ];

  _AntalyaPlace? _selected;

  Future<void> _addToTrip(_AntalyaPlace place) async {
    final added = await TripStorage.addStopToDestination(
      destination: 'Antalya',
      stop: ItineraryStop(
        time: place.time,
        title: place.name,
        description: place.description,
        category: place.category,
      ),
    );

    if (!mounted) return;

    final message = added
        ? '${place.name} Antalya gezi planına eklendi.'
        : 'Kayıtlı Antalya planı bulunamadı veya bu nokta zaten ekli. Önce Antalya gezisi oluştur.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openDirections(_AntalyaPlace place) async {
    final lat = place.location.latitude;
    final lon = place.location.longitude;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Antalya haritası'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.navy,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _antalyaCenter,
              initialZoom: 12,
              onTap: (_, _) => setState(() => _selected = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.tripapp',
              ),
              MarkerLayer(
                markers: _places.map((place) {
                  final selected = identical(_selected, place);
                  return Marker(
                    point: place.location,
                    width: 46,
                    height: 46,
                    child: GestureDetector(
                      onTap: () => setState(() => _selected = place),
                      child: Icon(
                        Icons.location_on,
                        size: selected ? 44 : 36,
                        color: selected ? AppTheme.navy : AppTheme.teal,
                      ),
                    ),
                  );
                }).toList(),
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    '© OpenStreetMap contributors',
                    onTap: () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Text(
                  '${_places.length} keşif noktası · İşaretlere dokunarak detayları aç',
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          if (_selected != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 18,
              child: _placeCard(_selected!),
            ),
        ],
      ),
    );
  }

  Widget _placeCard(_AntalyaPlace place) {
    return Material(
      color: Colors.white,
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    place.name,
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _selected = null),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              '${place.category} · Önerilen saat ${place.time}',
              style: const TextStyle(color: AppTheme.teal, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              place.description,
              style: const TextStyle(color: AppTheme.muted, height: 1.4),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openDirections(place),
                    icon: const Icon(Icons.directions),
                    label: const Text('Yol tarifi'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _addToTrip(place),
                    icon: const Icon(Icons.add),
                    label: const Text('Geziye ekle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
