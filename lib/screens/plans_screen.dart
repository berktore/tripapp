import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../models/trip_plan.dart';
import '../services/trip_storage.dart';
import '../services/weather_service.dart';
import '../theme/app_theme.dart';
import 'trip_map_screen.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  List<TripPlan> trips = [];
  bool loading = true;
  bool favoritesOnly = false;

  @override
  void initState() {
    super.initState();
    loadTrips();
  }

  Future<void> loadTrips() async {
    if (mounted) {
      setState(() => loading = true);
    }

    final result = await TripStorage.loadTrips();

    if (!mounted) return;

    setState(() {
      trips = result.trips;
      loading = false;
    });

    if (result.skipped > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.skipped} gezi kaydı okunamadı ve atlandı. '
            'Diğer planların korunuyor.',
          ),
        ),
      );
    }
  }

  Future<void> deleteTrip(TripPlan trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Geziyi sil'),
        content: Text(
          '${trip.destination} planını silmek istediğine emin misin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await TripStorage.deleteTrip(trip.id);
    await loadTrips();

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Gezi planı silindi.')));
  }

  Future<void> toggleFavorite(TripPlan trip) async {
    final isFavorite = await TripStorage.toggleFavorite(trip.id);

    if (!mounted) return;

    if (isFavorite == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gezi planı bulunamadı.')),
      );
      return;
    }

    await loadTrips();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFavorite
              ? '${trip.destination} favorilere eklendi.'
              : '${trip.destination} favorilerden çıkarıldı.',
        ),
      ),
    );
  }

  String formatDate(DateTime date) {
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final visibleTrips = favoritesOnly
        ? trips.where((trip) => trip.isFavorite).toList()
        : trips;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadTrips,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 15),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Planlarım',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.navy,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Hayalini kurduğun yolculuklar burada.',
                        style: TextStyle(fontSize: 14, color: AppTheme.muted),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(17),
                        decoration: BoxDecoration(
                          color: AppTheme.navy,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.luggage_rounded,
                              color: Color(0xFFBDEDE7),
                              size: 35,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Yolculuk koleksiyonun',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${trips.length} kayıtlı gezi planın var',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          ChoiceChip(
                            label: Text('Tümü (${trips.length})'),
                            selected: !favoritesOnly,
                            selectedColor: AppTheme.softTeal,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: !favoritesOnly
                                  ? AppTheme.navy
                                  : AppTheme.muted,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            onSelected: (_) =>
                                setState(() => favoritesOnly = false),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(
                              'Favoriler '
                              '(${trips.where((trip) => trip.isFavorite).length})',
                            ),
                            selected: favoritesOnly,
                            selectedColor: AppTheme.softTeal,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: favoritesOnly
                                  ? AppTheme.navy
                                  : AppTheme.muted,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            onSelected: (_) =>
                                setState(() => favoritesOnly = true),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.teal),
                  ),
                )
              else if (visibleTrips.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _emptyState(
                    favoritesOnly: favoritesOnly && trips.isNotEmpty,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 5, 20, 30),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final trip = visibleTrips[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _tripCard(trip),
                      );
                    }, childCount: visibleTrips.length),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState({bool favoritesOnly = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: Color(0xFFE1F3F0),
                shape: BoxShape.circle,
              ),
              child: Icon(
                favoritesOnly ? Icons.favorite_border : Icons.map_outlined,
                size: 43,
                color: AppTheme.teal,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              favoritesOnly
                  ? 'Henüz favori gezin yok.'
                  : 'Henüz bir gezi planın yok.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.navy,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              favoritesOnly
                  ? 'Bir planın kalbindeki simgeye dokunarak favorilere ekle.'
                  : 'Ana sayfadan ilk yolculuğunu planlamaya başlayabilirsin.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.muted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tripCard(TripPlan trip) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        borderRadius: BorderRadius.circular(21),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip)),
          );

          if (mounted) await loadTrips();
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(21),
                ),
                child: DestinationPhoto(
                  destination: trip.destination,
                  imageUrl: trip.imageUrl,
                  height: 155,
                  width: double.infinity,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            trip.destination,
                            style: const TextStyle(
                              color: AppTheme.navy,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: trip.isFavorite
                              ? 'Favorilerden çıkar'
                              : 'Favorilere ekle',
                          onPressed: () => toggleFavorite(trip),
                          icon: Icon(
                            trip.isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: trip.isFavorite
                                ? Colors.redAccent
                                : AppTheme.muted,
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'delete') {
                              deleteTrip(trip);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Geziyi sil'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      '${trip.duration} günlük yolculuk',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _infoRow(
                      Icons.calendar_month_outlined,
                      '${formatDate(trip.startDate)} - '
                      '${formatDate(trip.endDate)}',
                    ),
                    const SizedBox(height: 10),
                    _infoRow(Icons.people_outline, trip.travelers),
                    const SizedBox(height: 10),
                    _infoRow(
                      Icons.account_balance_wallet_outlined,
                      trip.budget,
                    ),
                    const SizedBox(height: 15),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: trip.travelStyles.map((style) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF7F5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            style,
                            style: const TextStyle(
                              color: AppTheme.navy,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 13),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Detayları görüntüle  →',
                        style: TextStyle(
                          color: AppTheme.teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppTheme.teal),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// GEZİ DETAY EKRANI

class TripDetailScreen extends StatefulWidget {
  final TripPlan trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late TripPlan _trip;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
  }

  bool get _hasCoordinates => _trip.itinerary.any(
    (day) => day.stops.any((stop) => stop.hasCoordinates),
  );

  String formatDate(DateTime date) {
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _deleteStop(ItineraryDay day, ItineraryStop stop) async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Durağı kaldır'),
        content: Text('${stop.title} planından kaldırılsın mı?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busy = true);

    final removed = await TripStorage.removeStop(
      tripId: _trip.id,
      dayNumber: day.dayNumber,
      title: stop.title,
      osmId: stop.osmId,
    );

    final result = await TripStorage.loadTrips();
    final updated = result.trips.where((trip) => trip.id == _trip.id).toList();

    if (!mounted) return;

    setState(() {
      _busy = false;
      if (updated.isNotEmpty) _trip = updated.first;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removed
              ? '${stop.title} plandan kaldırıldı.'
              : 'Durak kaldırılamadı; plan değişmedi.',
        ),
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    final isFavorite = await TripStorage.toggleFavorite(_trip.id);

    if (!mounted) return;

    if (isFavorite == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gezi planı bulunamadı.')),
      );
      return;
    }

    setState(() => _trip = _trip.copyWith(isFavorite: isFavorite));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFavorite ? 'Favorilere eklendi.' : 'Favorilerden çıkarıldı.',
        ),
      ),
    );
  }

  Future<void> _sharePlan() async {
    final buffer = StringBuffer()
      ..writeln('${_trip.destination} · ${_trip.duration} günlük gezi planı')
      ..writeln(
        '${formatDate(_trip.startDate)} - ${formatDate(_trip.endDate)}',
      )
      ..writeln('${_trip.travelers} · ${_trip.budget}')
      ..writeln();

    for (final day in _trip.itinerary) {
      buffer.writeln('${day.dayNumber}. Gün');
      for (final stop in day.stops) {
        buffer.writeln('${stop.time} · ${stop.title}');
      }
      buffer.writeln();
    }

    buffer.writeln(
      'TripApp ile planlandı. Mekân verisi: © OpenStreetMap katkıda '
      'bulunanlar (ODbL).',
    );

    await Clipboard.setData(ClipboardData(text: buffer.toString()));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Gezi planı panoya kopyalandı; dilediğin uygulamada paylaşabilirsin.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Gezi detayları'),
        actions: [
          IconButton(
            tooltip: _trip.isFavorite
                ? 'Favorilerden çıkar'
                : 'Favorilere ekle',
            onPressed: _toggleFavorite,
            icon: Icon(
              _trip.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: _trip.isFavorite ? Colors.redAccent : AppTheme.navy,
            ),
          ),
          IconButton(
            tooltip: 'Planı paylaş',
            onPressed: _sharePlan,
            icon: const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            tooltip: 'Haritada göster',
            onPressed: _hasCoordinates
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TripMapScreen(trip: _trip),
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.map_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: DestinationPhoto(
              destination: _trip.destination,
              imageUrl: _trip.imageUrl,
              height: 210,
              width: double.infinity,
            ),
          ),
          const SizedBox(height: 23),
          Text(
            _trip.destination,
            style: const TextStyle(
              color: AppTheme.navy,
              fontSize: 29,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_trip.duration} günlük yolculuk',
            style: const TextStyle(color: AppTheme.muted, fontSize: 15),
          ),
          const SizedBox(height: 25),
          _detailCard(
            'Seyahat tarihleri',
            '${formatDate(_trip.startDate)} - ${formatDate(_trip.endDate)}',
            Icons.calendar_month_outlined,
          ),
          _detailCard('Yolcular', _trip.travelers, Icons.people_outline),
          _detailCard(
            'Bütçe',
            _trip.budget,
            Icons.account_balance_wallet_outlined,
          ),
          _detailCard(
            'Tatil tarzı',
            _trip.travelStyles.join(', '),
            Icons.favorite_border,
          ),
          if (_hasCoordinates) ...[
            const SizedBox(height: 4),
            _WeatherSection(trip: _trip),
          ],
          const SizedBox(height: 15),
          const Text(
            'Günlük gezi programın',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (_trip.itinerary.isEmpty)
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF7F5),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Bu gezi eski bir kayıt olduğu için günlük programı bulunmuyor. '
                'Yeni oluşturacağın gezilerde program otomatik kaydedilecek.',
                style: TextStyle(color: AppTheme.muted, height: 1.5),
              ),
            )
          else
            ..._trip.itinerary.map(
              (day) => Container(
                margin: const EdgeInsets.only(bottom: 13),
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${day.dayNumber}. Gün · ${day.title}',
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatDate(_trip.dateForDay(day.dayNumber)),
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 13),
                    ...day.stops.map(
                      (stop) => Padding(
                        padding: const EdgeInsets.only(bottom: 13),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 54,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF7F5),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                stop.time,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppTheme.teal,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stop.title,
                                    style: const TextStyle(
                                      color: AppTheme.navy,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    stop.description,
                                    style: const TextStyle(
                                      color: AppTheme.muted,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    stop.category,
                                    style: const TextStyle(
                                      color: AppTheme.teal,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (stop.openingHours != null) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      'Çalışma saatleri: '
                                      '${stop.openingHours}',
                                      style: const TextStyle(
                                        color: AppTheme.muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                  if (stop.needsAttribution) ...[
                                    const SizedBox(height: 4),
                                    InkWell(
                                      onTap: () => launchUrl(
                                        Uri.parse(stop.sourceUrl!),
                                        mode: LaunchMode.externalApplication,
                                      ),
                                      child: const Text(
                                        'Kaynak: Wikipedia (CC BY-SA)',
                                        style: TextStyle(
                                          color: AppTheme.teal,
                                          fontSize: 10,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Durağı kaldır',
                              onPressed: _busy
                                  ? null
                                  : () => _deleteStop(day, stop),
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                size: 20,
                                color: AppTheme.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 6),
          const Text(
            'Mekân verisi: © OpenStreetMap katkıda bulunanlar (ODbL). '
            'Wikipedia metinleri CC BY-SA lisanslıdır.',
            style: TextStyle(color: AppTheme.muted, fontSize: 10, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _detailCard(String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.teal, size: 23),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// HAVA DURUMU

class _WeatherSection extends StatefulWidget {
  const _WeatherSection({required this.trip});

  final TripPlan trip;

  @override
  State<_WeatherSection> createState() => _WeatherSectionState();
}

class _WeatherSectionState extends State<_WeatherSection> {
  Future<WeatherResult>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<WeatherResult>? _load() {
    final center = _centerOf(widget.trip);
    if (center == null) return null;

    return WeatherService().getForecast(
      latitude: center.$1,
      longitude: center.$2,
      startDate: widget.trip.startDate,
      endDate: widget.trip.endDate,
    );
  }

  (double, double)? _centerOf(TripPlan trip) {
    if (trip.latitude != null && trip.longitude != null) {
      return (trip.latitude!, trip.longitude!);
    }

    for (final day in trip.itinerary) {
      for (final stop in day.stops) {
        if (stop.hasCoordinates) {
          return (stop.latitude!, stop.longitude!);
        }
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: FutureBuilder<WeatherResult>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text(
                  'Hava durumu kontrol ediliyor...',
                  style: TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
              ],
            );
          }

          if (snapshot.hasError) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hava durumu',
                  style: TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  snapshot.error.toString(),
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            );
          }

          final result = snapshot.data;
          if (result == null) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.wb_sunny_outlined,
                    color: AppTheme.teal,
                    size: 21,
                  ),
                  SizedBox(width: 9),
                  Text(
                    'Hava durumu',
                    style: TextStyle(
                      color: AppTheme.navy,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (result.note != null) ...[
                const SizedBox(height: 7),
                Text(
                  result.note!,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
              if (result.hasData) ...[
                const SizedBox(height: 11),
                ...result.days.map(
                  (day) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 52,
                          child: Text(
                            _shortDate(day.date),
                            style: const TextStyle(
                              color: AppTheme.navy,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          _iconFor(day.code),
                          size: 18,
                          color: AppTheme.teal,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            WeatherService.descriptionForCode(day.code),
                            style: const TextStyle(
                              color: AppTheme.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          '${day.minTemperature.round()}° / '
                          '${day.maxTemperature.round()}°',
                          style: const TextStyle(
                            color: AppTheme.navy,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (day.precipitationProbability != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '%${day.precipitationProbability}',
                            style: const TextStyle(
                              color: AppTheme.teal,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _shortDate(DateTime date) {
    const weekdays = [
      'Pzt',
      'Sal',
      'Çar',
      'Per',
      'Cum',
      'Cmt',
      'Paz',
    ];
    return '${weekdays[date.weekday - 1]} ${date.day}.${date.month}';
  }

  IconData _iconFor(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code <= 3) return Icons.wb_cloudy_rounded;
    if (code == 45 || code == 48) return Icons.foggy;
    if (code >= 51 && code <= 67) return Icons.grain_rounded;
    if (code >= 71 && code <= 77) return Icons.ac_unit_rounded;
    if (code >= 80 && code <= 82) return Icons.umbrella_rounded;
    if (code >= 95) return Icons.thunderstorm_rounded;
    return Icons.cloud_outlined;
  }
}

// DESTİNASYONA ÖZEL GÖRSEL

class DestinationPhoto extends StatefulWidget {
  final String destination;
  final String? imageUrl;
  final double height;
  final double width;

  const DestinationPhoto({
    super.key,
    required this.destination,
    this.imageUrl,
    required this.height,
    required this.width,
  });

  static const Map<String, Map<String, String>> cityImages = {
    'new york': {
      'image':
          'https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?w=1200',
      'landmark': 'Manhattan • New York',
    },
    'roma': {
      'image':
          'https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=1200',
      'landmark': 'Kolezyum • Roma',
    },
    'rome': {
      'image':
          'https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=1200',
      'landmark': 'Kolezyum • Roma',
    },
    'paris': {
      'image':
          'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=1200',
      'landmark': 'Eyfel Kulesi • Paris',
    },
    'kyoto': {
      'image':
          'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=1200',
      'landmark': 'Geleneksel Kyoto',
    },
    'istanbul': {
      'image':
          'https://images.unsplash.com/photo-1524231757912-21f4fe3a7200?w=1200',
      'landmark': 'İstanbul • Boğaz',
    },
    'kapadokya': {
      'image':
          'https://images.unsplash.com/photo-1570939274717-7eda259b50ed?w=1200',
      'landmark': 'Peri Bacaları • Kapadokya',
    },
    'santorini': {
      'image':
          'https://images.unsplash.com/photo-1533105079780-92b9be482077?w=1200',
      'landmark': 'Santorini • Yunanistan',
    },
    'bali': {
      'image':
          'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=1200',
      'landmark': 'Bali • Endonezya',
    },
  };

  @override
  State<DestinationPhoto> createState() => _DestinationPhotoState();
}

class _DestinationPhotoState extends State<DestinationPhoto> {
  String? adanaImage;
  bool loadingAdanaImage = false;

  bool get isAdana => widget.destination.trim().toLowerCase() == 'adana';

  @override
  void initState() {
    super.initState();
    if (isAdana) {
      loadAdanaImage();
    }
  }

  @override
  void didUpdateWidget(covariant DestinationPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destination != widget.destination && isAdana) {
      adanaImage = null;
      loadAdanaImage();
    }
  }

  Future<void> loadAdanaImage() async {
    if (loadingAdanaImage) return;
    setState(() => loadingAdanaImage = true);

    try {
      final uri = Uri.https('commons.wikimedia.org', '/w/api.php', {
        'action': 'query',
        'generator': 'search',
        'gsrsearch': 'filetype:bitmap Adana Taşköprü Turkey',
        'gsrnamespace': '6',
        'gsrlimit': '10',
        'prop': 'imageinfo',
        'iiprop': 'url',
        'iiurlwidth': '1200',
        'format': 'json',
        'origin': '*',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw Exception('Adana görseli alınamadı.');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final pages = data['query']?['pages'] as Map<String, dynamic>?;
      String? foundImage;

      if (pages != null) {
        for (final pageValue in pages.values) {
          final page = pageValue as Map<String, dynamic>;
          final imageInfo = page['imageinfo'] as List<dynamic>?;
          if (imageInfo == null || imageInfo.isEmpty) continue;

          final info = imageInfo.first as Map<String, dynamic>;
          final candidate = info['thumburl'] ?? info['url'];

          if (candidate != null &&
              candidate.toString().startsWith('https://')) {
            foundImage = candidate.toString();
            break;
          }
        }
      }

      if (mounted) {
        setState(() {
          adanaImage = foundImage;
          loadingAdanaImage = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => loadingAdanaImage = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = widget.destination.trim().toLowerCase();
    final city = DestinationPhoto.cityImages[key];

    final savedImage = widget.imageUrl?.trim();
    if (savedImage != null && savedImage.isNotEmpty) {
      return _photo(savedImage, widget.destination);
    }

    if (isAdana) {
      if (adanaImage == null) {
        return _fallback(
          label: 'Adana • Taşköprü',
          showLoading: loadingAdanaImage,
        );
      }
      return _photo(adanaImage!, 'Adana • Taşköprü');
    }

    if (city == null) {
      return _fallback();
    }

    return _photo(city['image']!, city['landmark']!);
  }

  Widget _photo(String imageUrl, String landmark) {
    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(label: landmark),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(15, 28, 15, 13),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC082D3D)],
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_city_rounded,
                    color: Color(0xFFBDEDE7),
                    size: 19,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      landmark,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback({String? label, bool showLoading = false}) {
    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: Container(
        color: AppTheme.navy,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: showLoading
                  ? const CircularProgressIndicator(color: Color(0xFFBDEDE7))
                  : const Icon(
                      Icons.location_city_rounded,
                      color: Color(0xFFBDEDE7),
                      size: 55,
                    ),
            ),
            if (label != null)
              Positioned(
                left: 15,
                right: 15,
                bottom: 13,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
