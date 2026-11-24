import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/trip_plan.dart';
import '../theme/app_theme.dart';

/// Kayıtlı bir gezinin gerçek duraklarını haritada gösterir.
/// Konumlar OSM verisinden geldiği için uydurma nokta içermez.
class TripMapScreen extends StatefulWidget {
  const TripMapScreen({super.key, required this.trip});

  final TripPlan trip;

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  int? _selectedDay;
  ItineraryStop? _selectedStop;

  List<ItineraryDay> get _daysWithCoordinates => widget.trip.itinerary
      .where(
        (day) => day.stops.any((stop) => stop.hasCoordinates),
      )
      .toList();

  List<LatLng> get _visiblePoints {
    final days = _selectedDay == null
        ? _daysWithCoordinates
        : _daysWithCoordinates
              .where((day) => day.dayNumber == _selectedDay)
              .toList();

    return days
        .expand((day) => day.stops)
        .where((stop) => stop.hasCoordinates)
        .map((stop) => LatLng(stop.latitude!, stop.longitude!))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final points = _visiblePoints;

    if (points.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('Gezi haritası')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Text(
              'Bu gezide koordinat bilgisi olan durak bulunmuyor.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('${widget.trip.destination} haritası'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCameraFit: points.length == 1
                  ? null
                  : CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(points),
                      padding: const EdgeInsets.all(60),
                    ),
              initialCenter: points.first,
              initialZoom: points.length == 1 ? 13 : 12,
              onTap: (_, _) => setState(() => _selectedStop = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tripapp.mobile',
              ),
              if (points.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: points,
                      strokeWidth: 4,
                      color: AppTheme.teal,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: _buildMarkers(),
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
            top: 12,
            left: 12,
            right: 12,
            child: _daySelector(),
          ),
          if (_selectedStop != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 18,
              child: _stopCard(_selectedStop!),
            ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    var visitNumber = 0;

    for (final day in _daysWithCoordinates) {
      if (_selectedDay != null && day.dayNumber != _selectedDay) continue;

      for (final stop in day.stops) {
        if (!stop.hasCoordinates) continue;
        visitNumber++;

        final selected = identical(_selectedStop, stop);
        markers.add(
          Marker(
            point: LatLng(stop.latitude!, stop.longitude!),
            width: 44,
            height: 44,
            child: GestureDetector(
              onTap: () => setState(() => _selectedStop = stop),
              child: Container(
                decoration: BoxDecoration(
                  color: selected ? AppTheme.navy : AppTheme.teal,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '$visitNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  Widget _daySelector() {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _dayChip(label: 'Tümü', day: null),
          for (final day in _daysWithCoordinates)
            _dayChip(label: '${day.dayNumber}. Gün', day: day.dayNumber),
        ],
      ),
    );
  }

  Widget _dayChip({required String label, required int? day}) {
    final selected = _selectedDay == day;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppTheme.teal,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppTheme.navy,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) {
          setState(() {
            _selectedDay = day;
            _selectedStop = null;
          });
        },
      ),
    );
  }

  Widget _stopCard(ItineraryStop stop) {
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
                    stop.title,
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _selectedStop = null),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              '${stop.time} · ${stop.category}',
              style: const TextStyle(color: AppTheme.teal, fontSize: 12),
            ),
            if (stop.openingHours != null) ...[
              const SizedBox(height: 6),
              Text(
                'Çalışma saatleri: ${stop.openingHours}',
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 11,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              stop.description,
              style: const TextStyle(color: AppTheme.muted, height: 1.4),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openDirections(stop),
                icon: const Icon(Icons.directions),
                label: const Text('Yol tarifi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDirections(ItineraryStop stop) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination='
      '${stop.latitude},${stop.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
