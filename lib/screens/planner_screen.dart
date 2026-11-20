
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/trip_plan.dart';
import '../services/trip_storage.dart';
import '../services/destination_image_service.dart';
import '../services/destination_places_service.dart';
import '../theme/app_theme.dart';
import 'plans_screen.dart';

class PlannerScreen extends StatefulWidget {
  final String? initialDestination;

  const PlannerScreen({super.key, this.initialDestination});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final destinationController = TextEditingController();
  final focusNode = FocusNode();

  Timer? debounce;

  String? selectedPlace;
  String budget = 'Orta';
  String travelers = '2 kişi';

  DateTimeRange? travelDates;

  final Set<String> selectedStyles = {};

  bool loading = false;
  bool showSuggestions = true;

  List<Map<String, String>> suggestions = [];

  final List<String> travelStyles = [
    'Deniz',
    'Kültür',
    'Doğa',
    'Macera',
    'Gastronomi',
    'Alışveriş',
    'Gece hayatı',
    'Dinlenme',
  ];

  final List<Map<String, String>> popularPlaces = [
    {
      'name': 'Kapadokya',
      'country': 'Türkiye',
      'image':
          'https://images.unsplash.com/photo-1570939274717-7eda259b50ed?w=600',
    },
    {
      'name': 'Santorini',
      'country': 'Yunanistan',
      'image':
          'https://images.unsplash.com/photo-1533105079780-92b9be482077?w=600',
    },
    {
      'name': 'Roma',
      'country': 'İtalya',
      'image':
          'https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=600',
    },
    {
      'name': 'Kyoto',
      'country': 'Japonya',
      'image':
          'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=600',
    },
    {
      'name': 'Paris',
      'country': 'Fransa',
      'image':
          'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=600',
    },
    {
      'name': 'Bali',
      'country': 'Endonezya',
      'image':
          'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=600',
    },
  ];

  @override
  void initState() {
    super.initState();
    suggestions = popularPlaces;

    final initialDestination = widget.initialDestination?.trim();

    if (initialDestination != null && initialDestination.isNotEmpty) {
      selectedPlace = initialDestination;
      destinationController.text = initialDestination;
      showSuggestions = false;
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    destinationController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void searchPlaces(String query) {
    debounce?.cancel();

    setState(() {
      selectedPlace = null;
      showSuggestions = true;

      if (query.trim().isEmpty) {
        suggestions = popularPlaces;
        loading = false;
      } else {
        loading = true;
      }
    });

    if (query.trim().isEmpty) return;

    debounce = Timer(
      const Duration(milliseconds: 400),
      () => fetchPlaces(query.trim()),
    );
  }

  Future<void> fetchPlaces(String query) async {
    try {
      final uri = Uri.https(
        'geocoding-api.open-meteo.com',
        '/v1/search',
        {
          'name': query,
          'count': '8',
          'language': 'tr',
          'format': 'json',
        },
      );

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Destinasyon aranamadı.');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];

      final places = results
          .map((item) {
            final place = item as Map<String, dynamic>;

            return {
              'name': place['name']?.toString() ?? '',
              'country': [
                place['admin1'],
                place['country'],
              ]
                  .where(
                    (e) => e != null && e.toString().isNotEmpty,
                  )
                  .join(', '),
              'image': '',
            };
          })
          .where((place) => place['name']!.isNotEmpty)
          .toList();

      if (!mounted || destinationController.text.trim() != query) {
        return;
      }

      setState(() {
        suggestions = places;
        loading = false;
      });
    } catch (_) {
      if (!mounted || destinationController.text.trim() != query) {
        return;
      }

      setState(() {
        suggestions = popularPlaces.where((place) {
          return place['name']!
              .toLowerCase()
              .contains(query.toLowerCase());
        }).toList();

        loading = false;
      });
    }
  }

  void choosePlace(Map<String, String> place) {
    setState(() {
      selectedPlace = place['name'];
      destinationController.text = place['name']!;
      showSuggestions = false;
    });

    focusNode.unfocus();
  }

  Future<void> selectDates() async {
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
      initialDateRange: travelDates,
      helpText: 'Seyahat tarihlerini seç',
      saveText: 'TARİHLERİ ONAYLA',
      locale: const Locale('tr', 'TR'),
    );

    if (picked != null) {
      setState(() {
        travelDates = picked;
      });
    }
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

  int get tripDays {
    if (travelDates == null) return 0;

    return travelDates!.end.difference(travelDates!.start).inDays + 1;
  }

  InputDecoration fieldDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppTheme.navy),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget sectionTitle(
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE1F3F0),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppTheme.navy, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navy,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFEAF0EF)),
      ),
      child: child,
    );
  }

  Future<void> createPlan() async {
    if (loading) return;

    if (selectedPlace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Önce gitmek istediğin destinasyonu seç.'),
        ),
      );
      return;
    }

    if (travelDates == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen seyahat tarihlerini seç.'),
        ),
      );
      return;
    }

    if (selectedStyles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('En az bir tatil tarzı seçmelisin.'),
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final now = DateTime.now();

      final imageUrl = await DestinationImageService.getImageUrl(
        selectedPlace!,
      );

      final itinerary = await DestinationPlacesService().buildItinerary(
        destination: selectedPlace!,
        dayCount: travelDates!.end.difference(travelDates!.start).inDays + 1,
        styles: selectedStyles.toList(),
        budget: budget,
      );

      if (itinerary.every((day) => day.stops.isEmpty)) {
        throw Exception(
          'Bu destinasyon için yeterli gezi noktası bulunamadı.',
        );
      }

      final trip = TripPlan(
        id: now.microsecondsSinceEpoch.toString(),
        destination: selectedPlace!,
        imageUrl: imageUrl,
        startDate: travelDates!.start,
        endDate: travelDates!.end,
        travelers: travelers,
        budget: budget,
        travelStyles: selectedStyles.toList(),
        createdAt: now,
        itinerary: itinerary,
      );

      await TripStorage.saveTrip(trip);

      if (!mounted) return;

      setState(() => loading = false);

      final goToPlans = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text('Gezi planın kaydedildi!'),
            content: const Text(
              'Yolculuğun artık Planlarım bölümünde seni bekliyor.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Planlarımı görüntüle'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      // Liste ekranına uğramadan doğrudan yeni planın detayını aç.
      if (goToPlans == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TripDetailScreen(trip: trip),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gezi kaydedilemedi: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Gezi planla',
          style: TextStyle(
            color: AppTheme.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.navy,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          const Text(
            'Hayalindeki yolculuk nasıl olsun?',
            style: TextStyle(
              fontSize: 27,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: AppTheme.navy,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tercihlerini belirle, sana özel bir yolculuk hazırlayalım.',
            style: TextStyle(
              color: AppTheme.muted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 25),

          sectionTitle(
            'Nereye gitmek istiyorsun?',
            'Şehir veya ülke seç',
            Icons.location_on_outlined,
          ),
          sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: destinationController,
                  focusNode: focusNode,
                  onChanged: searchPlaces,
                  decoration: fieldDecoration(
                    'Şehir veya ülke ara...',
                    Icons.search_rounded,
                  ).copyWith(
                    suffixIcon: loading
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : destinationController.text.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  destinationController.clear();
                                  searchPlaces('');
                                },
                                icon: const Icon(Icons.close),
                              )
                            : null,
                  ),
                ),
                if (selectedPlace != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F5F1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: AppTheme.teal,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            '$selectedPlace seçildi',
                            style: const TextStyle(
                              color: AppTheme.navy,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              selectedPlace = null;
                              destinationController.clear();
                              suggestions = popularPlaces;
                              showSuggestions = true;
                            });

                            focusNode.requestFocus();
                          },
                          child: const Text('Değiştir'),
                        ),
                      ],
                    ),
                  ),
                ],
                if (showSuggestions) ...[
                  const SizedBox(height: 17),
                  Text(
                    destinationController.text.isEmpty
                        ? 'Popüler destinasyonlar'
                        : 'Arama sonuçları',
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (destinationController.text.isEmpty)
                    SizedBox(
                      height: 190,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: suggestions.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final place = suggestions[index];

                          return GestureDetector(
                            onTap: () => choosePlace(place),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                                width: 145,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      place['image']!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        color: AppTheme.navy,
                                        child: const Icon(
                                          Icons.landscape,
                                          color: Colors.white,
                                          size: 35,
                                        ),
                                      ),
                                    ),
                                    const DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Color(0xDD082D3D),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 11,
                                      right: 8,
                                      bottom: 12,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            place['name']!,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            place['country']!,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
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
                        },
                      ),
                    )
                  else if (suggestions.isEmpty && !loading)
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'Sonuç bulunamadı. Başka bir şehir deneyebilirsin.',
                        style: TextStyle(color: AppTheme.muted),
                      ),
                    )
                  else
                    ...suggestions.map((place) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE1F3F0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.location_on_outlined,
                            color: AppTheme.navy,
                          ),
                        ),
                        title: Text(
                          place['name']!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.navy,
                          ),
                        ),
                        subtitle: Text(place['country']!),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 15,
                        ),
                        onTap: () => choosePlace(place),
                      );
                    }),
                ],
              ],
            ),
          ),

          const SizedBox(height: 25),
          sectionTitle(
            'Ne zaman seyahat edeceksin?',
            'Gidiş ve dönüş tarihlerini belirle',
            Icons.calendar_month_outlined,
          ),
          GestureDetector(
            onTap: selectDates,
            child: sectionCard(
              child: Row(
                children: [
                  const Icon(
                    Icons.date_range_rounded,
                    color: AppTheme.teal,
                    size: 28,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          travelDates == null
                              ? 'Seyahat tarihlerini seç'
                              : '${formatDate(travelDates!.start)} - ${formatDate(travelDates!.end)}',
                          style: const TextStyle(
                            color: AppTheme.navy,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          travelDates == null
                              ? 'Gidiş ve dönüş tarihleri'
                              : '$tripDays günlük yolculuk',
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.muted,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 25),
          sectionTitle(
            'Kimlerle seyahat edeceksin?',
            'Yolculuk grubunu belirle',
            Icons.people_outline_rounded,
          ),
          sectionCard(
            child: DropdownButtonFormField<String>(
              initialValue: travelers,
              decoration: fieldDecoration(
                'Seyahat grubu',
                Icons.people_outline,
              ),
              items: const [
                'Tek başıma',
                '2 kişi',
                '3 kişi',
                '4 kişi',
                '5 kişi',
                '6 kişi',
                'Aile',
                'Arkadaşlarla',
              ].map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => travelers = value);
                }
              },
            ),
          ),

          const SizedBox(height: 25),
          sectionTitle(
            'Bütçen nasıl?',
            'Seyahat bütçeni belirle',
            Icons.account_balance_wallet_outlined,
          ),
          sectionCard(
            child: Wrap(
              spacing: 9,
              runSpacing: 9,
              children: ['Ekonomik', 'Orta', 'Konforlu', 'Lüks'].map((item) {
                final selected = budget == item;

                return ChoiceChip(
                  label: Text(item),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => budget = item);
                  },
                  selectedColor: const Color(0xFFDDF3EF),
                  backgroundColor: const Color(0xFFF5F8F8),
                  labelStyle: TextStyle(
                    color: selected ? AppTheme.navy : AppTheme.muted,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: selected
                        ? AppTheme.teal
                        : const Color(0xFFE7ECEB),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 25),
          sectionTitle(
            'Nasıl bir tatil hayal ediyorsun?',
            'Birden fazla seçenek işaretleyebilirsin',
            Icons.favorite_border_rounded,
          ),
          sectionCard(
            child: Wrap(
              spacing: 9,
              runSpacing: 9,
              children: travelStyles.map((style) {
                final selected = selectedStyles.contains(style);

                return FilterChip(
                  label: Text(style),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        selectedStyles.add(style);
                      } else {
                        selectedStyles.remove(style);
                      }
                    });
                  },
                  selectedColor: const Color(0xFFDDF3EF),
                  backgroundColor: const Color(0xFFF5F8F8),
                  checkmarkColor: AppTheme.teal,
                  labelStyle: TextStyle(
                    color: selected ? AppTheme.navy : AppTheme.muted,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: selected
                        ? AppTheme.teal
                        : const Color(0xFFE7ECEB),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 30),
          SizedBox(
            height: 58,
            child: ElevatedButton(
              onPressed: loading ? null : createPlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.teal,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppTheme.teal.withValues(alpha: 0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(Icons.auto_awesome_rounded),
                  const SizedBox(width: 10),
                  Text(
                    loading
                        ? 'Gerçek gezi noktaları bulunuyor...'
                        : 'Gezi planımı oluştur',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 19,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 13),
          const Center(
            child: Text(
              'Seyahatini birlikte güzelleştirelim.',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
