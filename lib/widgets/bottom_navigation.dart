import 'package:flutter/material.dart';

class TripBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  const TripBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: selectedIndex,
    onDestinationSelected: onDestinationSelected,
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        label: 'Ana Sayfa',
      ),
      NavigationDestination(
        icon: Icon(Icons.explore_outlined),
        label: 'Keşfet',
      ),
      NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Planlarım'),
      NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
    ],
  );
}
