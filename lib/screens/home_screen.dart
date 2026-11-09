import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'planner_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'TripApp.',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.navy,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                  const CircleAvatar(
                    backgroundColor: Color(0xFFDDF2EF),
                    child: Icon(Icons.person_outline, color: AppTheme.navy),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              const Text(
                'Yeni yerler, yeni hikâyeler.',
                style: TextStyle(
                  fontSize: 27,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bir sonraki yolculuğun seni bekliyor.',
                style: TextStyle(color: AppTheme.muted, fontSize: 14),
              ),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlannerScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.navy,
                    borderRadius: BorderRadius.circular(24),
                    image: const DecorationImage(
                      image: NetworkImage(
                        'https://images.unsplash.com/photo-1533105079780-92b9be482077?w=1000',
                      ),
                      fit: BoxFit.cover,
                      opacity: 0.25,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      const Text(
                        'Hayalindeki geziyi\nbirlikte planlayalım.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          height: 1.25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 17,
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
              const Row(
                children: [
                  Text(
                    'Şimdi keşfet',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.navy,
                    ),
                  ),
                  Spacer(),
                  Text(
                    'Tümünü gör',
                    style: TextStyle(
                      color: AppTheme.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    Image.network(
                      'https://images.unsplash.com/photo-1516483638261-f4dbaf036963?w=1200',
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      left: 18,
                      bottom: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'HAFTANIN ROTASI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Amalfi Kıyıları, İtalya',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                      image: 'photo-1570939274717-7eda259b50ed',
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
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            label: 'Keşfet',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            label: 'Planlarım',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class DestinationTile extends StatelessWidget {
  final String name;
  final String image;
  const DestinationTile({super.key, required this.name, required this.image});

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
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
