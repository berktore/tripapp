
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/destination_image_service.dart';
import 'planner_screen.dart';
import 'plans_screen.dart';
import 'destination_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;
  int plansRefreshKey = 0;

  Future<void> openPlanner() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const PlannerScreen(),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      setState(() {
        selectedIndex = 2;
        plansRefreshKey++;
      });
    }
  }

  void changeTab(int index) {
    setState(() {
      selectedIndex = index;

      if (index == 2) {
        plansRefreshKey++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeContent(onPlanTap: openPlanner),
      DiscoverScreen(onPlanTap: openPlanner),
      PlansScreen(key: ValueKey(plansRefreshKey)),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: IndexedStack(
          index: selectedIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFFEAF0EF),
        selectedIndex: selectedIndex,
        onDestinationSelected: changeTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Keşfet',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Planlarım',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ANA SAYFA
// ============================================================

class HomeContent extends StatelessWidget {
  final VoidCallback onPlanTap;

  const HomeContent({
    super.key,
    required this.onPlanTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding =
            constraints.maxWidth < 360 ? 14.0 : 20.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // RESPONSIVE ÜST MENÜ
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'TripApp.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize:
                            constraints.maxWidth < 300 ? 23 : 27,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.navy,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    onPressed: () {},
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: AppTheme.navy,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const CircleAvatar(
                    radius: 19,
                    backgroundColor: Color(0xFFDDF2EF),
                    child: Icon(
                      Icons.person_outline,
                      color: AppTheme.navy,
                      size: 21,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              const Text(
                'Merhaba, gezgin!',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Bir sonraki yolculuğun seni bekliyor.',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 22),

              // GEZİ PLANLAMA KARTI
              GestureDetector(
                onTap: onPlanTap,
                child: Container(
                  width: double.infinity,
                  height: 205,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.navy,
                    borderRadius: BorderRadius.circular(24),
                    image: const DecorationImage(
                      image: NetworkImage(
                        'https://images.unsplash.com/photo-1533105079780-92b9be482077?w=1200',
                      ),
                      fit: BoxFit.cover,
                      opacity: 0.38,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'SANA ÖZEL YOLCULUK',
                        style: TextStyle(
                          color: Color(0xFFBDEDE7),
                          fontSize: 11,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Flexible(
                        child: Text(
                          'Hayalindeki geziyi\nbirlikte planlayalım.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            height: 1.2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 17),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.teal,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Gezi planla',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 9),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Haftanın rotası',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navy,
                ),
              ),

              const SizedBox(height: 15),

              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.network(
                  'https://images.unsplash.com/photo-1516483638261-f4dbaf036963?w=1200',
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 220,
                    color: AppTheme.navy,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Popüler destinasyonlar',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navy,
                ),
              ),

              const SizedBox(height: 15),

              const Row(
                children: [
                  Expanded(
                    child: DestinationTile(
                      name: 'Kapadokya',
                      image: 'photo-1733035992715-86bb7d8adc73',
                    ),
                  ),
                  SizedBox(width: 13),
                  Expanded(
                    child: DestinationTile(
                      name: 'Santorini',
                      image: 'photo-1533105079780-92b9be482077',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              const Row(
                children: [
                  Expanded(
                    child: DestinationTile(
                      name: 'İstanbul',
                      image: 'photo-1524231757912-21f4fe3a7200',
                    ),
                  ),
                  SizedBox(width: 13),
                  Expanded(
                    child: DestinationTile(
                      name: 'Kyoto',
                      image: 'photo-1493976040374-85c8e12f0c0e',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// DESTİNASYON KARTI
// ============================================================

class DestinationTile extends StatelessWidget {
  final String name;
  final String image;

  const DestinationTile({
    super.key,
    required this.name,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(19),
      child: Stack(
        children: [
          Image.network(
            'https://images.unsplash.com/$image?w=700',
            height: 145,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              height: 145,
              color: AppTheme.navy,
            ),
          ),
          Positioned(
            left: 12,
            right: 8,
            bottom: 12,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// KEŞFET
// ============================================================

class DiscoverScreen extends StatefulWidget {
  final VoidCallback onPlanTap;

  const DiscoverScreen({
    super.key,
    required this.onPlanTap,
  });

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final searchController = TextEditingController();

  String selectedCategory = 'Tümü';
  String searchQuery = '';
  _Destination? selectedDestination;

  final categories = [
    'Tümü',
    'Türkiye',
    'Avrupa',
    'Amerika',
    'Asya',
  ];

  final destinations = const [
    _Destination(
      name: 'Adana',
      country: 'Türkiye',
      category: 'Türkiye',
      description: 'Taşköprü, Sabancı Camii ve Adana mutfağı.',
      image: '',
      imageSearch: 'Adana Taşköprü Turkey',
    ),
    _Destination(
      name: 'Kapadokya',
      country: 'Türkiye',
      category: 'Türkiye',
      description: 'Peri bacaları ve sıcak hava balonları.',
      image:
          'https://images.unsplash.com/photo-1570939274717-7eda259b50ed?w=900',
    ),
    _Destination(
      name: 'İstanbul',
      country: 'Türkiye',
      category: 'Türkiye',
      description: 'İki kıtayı birleştiren büyüleyici şehir.',
      image:
          'https://images.unsplash.com/photo-1524231757912-21f4fe3a7200?w=900',
    ),
    _Destination(
      name: 'Antalya',
      country: 'Türkiye',
      category: 'Türkiye',
      description: 'Akdeniz kıyıları ve tarihi Kaleiçi.',
      image:
          'https://images.unsplash.com/photo-1516483638261-f4dbaf036963?w=900',
    ),
    _Destination(
      name: 'Santorini',
      country: 'Yunanistan',
      category: 'Avrupa',
      description: 'Beyaz evler ve Ege manzaraları.',
      image:
          'https://images.unsplash.com/photo-1533105079780-92b9be482077?w=900',
    ),
    _Destination(
      name: 'Roma',
      country: 'İtalya',
      category: 'Avrupa',
      description: 'Kolezyum, tarih ve İtalyan lezzetleri.',
      image:
          'https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=900',
    ),
    _Destination(
      name: 'Paris',
      country: 'Fransa',
      category: 'Avrupa',
      description: 'Eyfel Kulesi ve sanat dolu sokaklar.',
      image:
          'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=900',
    ),
    _Destination(
      name: 'New York',
      country: 'ABD',
      category: 'Amerika',
      description: 'Manhattan, Central Park ve Özgürlük Heykeli.',
      image:
          'https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?w=900',
    ),
    _Destination(
      name: 'Kyoto',
      country: 'Japonya',
      category: 'Asya',
      description: 'Tapınaklar ve geleneksel Japon kültürü.',
      image:
          'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=900',
    ),
    _Destination(
      name: 'Bali',
      country: 'Endonezya',
      category: 'Asya',
      description: 'Tropik doğa ve huzurlu plajlar.',
      image:
          'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=900',
    ),
  ];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<_Destination> get filteredDestinations {
    return destinations.where((destination) {
      final categoryMatches =
          selectedCategory == 'Tümü' ||
          destination.category == selectedCategory;

      final query = searchQuery.trim().toLowerCase();

      final searchMatches =
          query.isEmpty ||
          destination.name.toLowerCase().contains(query) ||
          destination.country.toLowerCase().contains(query);

      return categoryMatches && searchMatches;
    }).toList();
  }

  List<_Destination> get suggestions {
    final query = searchQuery.trim().toLowerCase();

    if (query.isEmpty || selectedDestination != null) {
      return [];
    }

    return destinations
        .where((destination) {
          return destination.name.toLowerCase().contains(query) ||
              destination.country.toLowerCase().contains(query);
        })
        .take(5)
        .toList();
  }

  void selectDestination(_Destination destination) {
    setState(() {
      selectedDestination = destination;
      searchController.text = destination.name;
      searchQuery = destination.name;
      selectedCategory = 'Tümü';
    });

    FocusScope.of(context).unfocus();
  }

  void clearSelection() {
    setState(() {
      selectedDestination = null;
      searchController.clear();
      searchQuery = '';
    });
  }

  void openDestinationDetails(_Destination destination) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DestinationDetailScreen(
          name: destination.name,
          country: destination.country,
          image: destination.image,
          description: destination.description,
          onPlanTap: widget.onPlanTap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredDestinations;
    final matchingSuggestions = suggestions;

    return CustomScrollView(
      keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const Text(
                'Dünyayı keşfet.',
                style: TextStyle(
                  color: AppTheme.navy,
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 7),

              const Text(
                'Bir sonraki maceran için ilham al.',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 22),

              // ARAMA ALANI
              TextField(
                controller: searchController,
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                    selectedDestination = null;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Şehir veya ülke ara...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppTheme.teal,
                  ),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: clearSelection,
                          icon: const Icon(Icons.close_rounded),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 17),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              // ARAMA ÖNERİLERİ
              if (matchingSuggestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: const Color(0xFFE7ECEB),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x10000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: matchingSuggestions.map((destination) {
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(
                            horizontal: 14,
                          ),
                          onTap: () =>
                              selectDestination(destination),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF7F5),
                              borderRadius:
                                  BorderRadius.circular(11),
                            ),
                            child: const Icon(
                              Icons.location_on_outlined,
                              color: AppTheme.teal,
                            ),
                          ),
                          title: Text(
                            destination.name,
                            style: const TextStyle(
                              color: AppTheme.navy,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            destination.country,
                            style: const TextStyle(
                              color: AppTheme.muted,
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.north_west_rounded,
                            size: 17,
                            color: AppTheme.muted,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              // SEÇİLEN DESTİNASYON
              if (selectedDestination != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDF3EF),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: AppTheme.teal,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            selectedDestination!.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.navy,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        GestureDetector(
                          onTap: clearSelection,
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: AppTheme.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 25),

              // ÖNE ÇIKAN DESTİNASYON
              const Text(
                'ÖNE ÇIKAN DESTİNASYON',
                style: TextStyle(
                  color: AppTheme.teal,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              GestureDetector(
                onTap: widget.onPlanTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(23),
                  child: Stack(
                    children: [
                      Image.network(
                        'https://images.unsplash.com/photo-1533105079780-92b9be482077?w=1200',
                        height: 230,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          height: 230,
                          color: AppTheme.navy,
                        ),
                      ),
                      Container(
                        height: 230,
                        decoration: const BoxDecoration(
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
                      const Positioned(
                        left: 18,
                        right: 14,
                        bottom: 18,
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'YUNANİSTAN',
                              style: TextStyle(
                                color: Color(0xFFBDEDE7),
                                fontSize: 11,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Santorini',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 27,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Ege’nin eşsiz manzarasını keşfet.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Nereye gitmek istersin?',
                style: TextStyle(
                  color: AppTheme.navy,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 14),

              // BÖLGE FİLTRELERİ
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((category) {
                    final selected =
                        selectedCategory == category;

                    return Padding(
                      padding:
                          const EdgeInsets.only(right: 9),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            selectedCategory = category;
                          });
                        },
                        selectedColor: AppTheme.teal,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppTheme.navy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),

              // DESTİNASYON KARTLARI
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(
                    child: Text(
                      'Aradığın destinasyon bulunamadı.',
                      style: TextStyle(
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
                )
              else
                ...filtered.map((destination) {
                  return Padding(
                    padding:
                        const EdgeInsets.only(bottom: 15),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () =>
                            openDestinationDetails(destination),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final compact =
                                constraints.maxWidth < 300;

                            return Row(
                              children: [
                                ClipRRect(
                                  borderRadius:
                                      const BorderRadius.horizontal(
                                    left: Radius.circular(20),
                                  ),
                                  child:
                                      _DestinationDiscoverImage(
                                    destination: destination,
                                    width: compact ? 95 : 125,
                                    height: 125,
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.all(13),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          destination.country
                                              .toUpperCase(),
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppTheme.teal,
                                            fontSize: 10,
                                            letterSpacing: 1,
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          destination.name,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppTheme.navy,
                                            fontSize: 18,
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          destination.description,
                                          maxLines: 2,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppTheme.muted,
                                            fontSize: 11,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Row(
                                          mainAxisSize:
                                              MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                'Detayları keşfet',
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: AppTheme.teal,
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 5),
                                            Icon(
                                              Icons.arrow_forward_rounded,
                                              color: AppTheme.teal,
                                              size: 14,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  );
                }),
            ]),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// DESTİNASYON MODELİ
// ============================================================

class _Destination {
  final String name;
  final String country;
  final String category;
  final String description;
  final String image;
  final String? imageSearch;

  const _Destination({
    required this.name,
    required this.country,
    required this.category,
    required this.description,
    required this.image,
    this.imageSearch,
  });
}

// ============================================================
// DESTİNASYON GÖRSELİ
// ============================================================

class _DestinationDiscoverImage extends StatelessWidget {
  final _Destination destination;
  final double width;
  final double height;

  const _DestinationDiscoverImage({
    required this.destination,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: DestinationImageService.getImageUrl(
        destination.name,
      ),
      builder: (context, snapshot) {
        final url = snapshot.data;

        if (url == null || url.isEmpty) {
          return Container(
            width: width,
            height: height,
            color: const Color(0xFFE1F3F0),
            alignment: Alignment.center,
            child:
                snapshot.connectionState == ConnectionState.waiting
                    ? const CircularProgressIndicator(
                        color: AppTheme.teal,
                      )
                    : const Icon(
                        Icons.location_city_rounded,
                        color: AppTheme.teal,
                        size: 35,
                      ),
          );
        }

        return Image.network(
          url,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: width,
            height: height,
            color: const Color(0xFFE1F3F0),
            alignment: Alignment.center,
            child: const Icon(
              Icons.location_city_rounded,
              color: AppTheme.teal,
              size: 35,
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// PROFİL
// ============================================================

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: Color(0xFFDDF2EF),
              child: Icon(
                Icons.person_outline,
                size: 42,
                color: AppTheme.navy,
              ),
            ),
            SizedBox(height: 15),
            Text(
              'Profilim',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: AppTheme.navy,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Profil ayarları yakında burada.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
