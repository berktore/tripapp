import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final destination = TextEditingController();
  final focusNode = FocusNode();

  Timer? debounce;
  String budget = 'Orta';
  String travelers = '2 kişi';
  bool loading = false;
  bool showSuggestions = false;
  String? selectedPlace;
  List<Map<String, String>> suggestions = [];

  final List<Map<String, String>> popularPlaces = [
    {
      'name': 'Kapadokya',
      'country': 'Türkiye',
      'emoji': '🎈',
      'image':
          'https://images.unsplash.com/photo-1570939274717-7eda259b50ed?w=600',
    },
    {
      'name': 'Santorini',
      'country': 'Yunanistan',
      'emoji': '🏝️',
      'image':
          'https://images.unsplash.com/photo-1533105079780-92b9be482077?w=600',
    },
    {
      'name': 'Roma',
      'country': 'İtalya',
      'emoji': '🏛️',
      'image':
          'https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=600',
    },
    {
      'name': 'Kyoto',
      'country': 'Japonya',
      'emoji': '⛩️',
      'image':
          'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=600',
    },
    {
      'name': 'Paris',
      'country': 'Fransa',
      'emoji': '🗼',
      'image':
          'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=600',
    },
    {
      'name': 'Bali',
      'country': 'Endonezya',
      'emoji': '🌴',
      'image':
          'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=600',
    },
  ];

  @override
  void initState() {
    super.initState();
    suggestions = popularPlaces;
    showSuggestions = true;
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

    debounce = Timer(const Duration(milliseconds: 350), () {
      fetchPlaces(query.trim());
    });
  }

  Future<void> fetchPlaces(String query) async {
    try {
      final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': query,
        'count': '6',
        'language': 'tr',
        'format': 'json',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Arama başarısız');
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
              ].where((e) => e != null && e.toString().isNotEmpty).join(', '),
              'emoji': '📍',
            };
          })
          .where((place) => place['name']!.isNotEmpty)
          .toList();

      if (!mounted) return;

      setState(() {
        suggestions = places;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        suggestions = popularPlaces.where((place) {
          return place['name']!.toLowerCase().contains(query.toLowerCase());
        }).toList();
        loading = false;
      });
    }
  }

  void choosePlace(Map<String, String> place) {
    setState(() {
      selectedPlace = place['name'];
      destination.text = place['name']!;
      showSuggestions = false;
    });
    focusNode.unfocus();
  }

  @override
  void dispose() {
    debounce?.cancel();
    destination.dispose();
    focusNode.dispose();
    super.dispose();
  }

  InputDecoration fieldDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppTheme.navy),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gezi planlayıcısı'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Text(
            'Hayalindeki yolculuk nasıl olsun?',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.bold,
              color: AppTheme.navy,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'Tercihlerini belirle, sana uygun bir rota hazırlayalım.',
            style: TextStyle(color: AppTheme.muted),
          ),
          const SizedBox(height: 28),

          const Text(
            'Nereye gitmek istiyorsun?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: destination,
            focusNode: focusNode,
            onChanged: searchPlaces,
            decoration:
                fieldDecoration(
                  'Şehir veya ülke ara...',
                  Icons.search_rounded,
                ).copyWith(
                  suffixIcon: loading
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : destination.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            destination.clear();
                            searchPlaces('');
                          },
                        )
                      : null,
                ),
          ),

          if (selectedPlace != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F7F4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.teal),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.teal),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$selectedPlace seçildi',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        selectedPlace = null;
                        destination.clear();
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
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(
                  destination.text.isEmpty
                      ? Icons.explore_rounded
                      : Icons.location_on_rounded,
                  color: AppTheme.teal,
                  size: 19,
                ),
                const SizedBox(width: 7),
                Text(
                  destination.text.isEmpty
                      ? 'Popüler destinasyonlar'
                      : 'Arama sonuçları',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (destination.text.isEmpty) ...[
              SizedBox(
                height: 205,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: suggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final place = suggestions[index];
                    return GestureDetector(
                      onTap: () => choosePlace(place),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(
                          width: 165,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                place['image'] ?? '',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppTheme.navy,
                                  child: const Icon(
                                    Icons.landscape,
                                    color: Colors.white,
                                    size: 38,
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
                                      Color(0xCC082D3D),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 12,
                                right: 12,
                                bottom: 13,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      place['name']!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      place['country']!,
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
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              if (suggestions.isEmpty && !loading)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Sonuç bulunamadı. Başka bir şehir deneyebilirsin.',
                  ),
                ),
              ...suggestions.map((place) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => choosePlace(place),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 43,
                              height: 43,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F7F5),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Text(
                                place['emoji']!,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    place['name']!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    place['country']!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 15,
                              color: AppTheme.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],

          const SizedBox(height: 22),
          const Text(
            'Kimlerle seyahat edeceksin?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 9),
          DropdownButtonFormField<String>(
            initialValue: travelers,
            items: [
              'Tek başıma',
              '2 kişi',
              'Aile',
              'Arkadaşlarla',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => travelers = v);
            },
            decoration: fieldDecoration('Seyahat grubu', Icons.people_outline),
          ),

          const SizedBox(height: 22),
          const Text(
            'Bütçen nasıl?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 9,
            children: ['Ekonomik', 'Orta', 'Konforlu'].map((e) {
              return ChoiceChip(
                label: Text(e),
                selected: budget == e,
                onSelected: (_) => setState(() => budget = e),
                selectedColor: const Color(0xFFDDF7F4),
              );
            }).toList(),
          ),

          const SizedBox(height: 30),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: () {
                if (selectedPlace == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Önce önerilerden bir destinasyon seç.'),
                    ),
                  );
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '$selectedPlace · $travelers · $budget seçildi. '
                      'AI rota oluşturma sonraki aşamada bağlanacak.',
                    ),
                  ),
                );
              },
              child: const Text(
                'Gezi planımı oluştur',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
