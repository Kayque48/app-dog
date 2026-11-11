import 'package:flutter/material.dart';

import '../widgets.dart';
import 'discover_screen.dart';
import 'feed_screen.dart';
import 'matches_screen.dart';
import 'places_screen.dart';
import 'profile_screen.dart';

/// Tela principal com as 5 abas. Em tablets usa uma barra lateral.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  static const _destinations = [
    (Icons.photo_library_outlined, Icons.photo_library, 'Feed'),
    (Icons.style_outlined, Icons.style, 'Descobrir'),
    (Icons.favorite_border, Icons.favorite, 'Encontros'),
    (Icons.park_outlined, Icons.park, 'Parques'),
    (Icons.person_outline, Icons.person, 'Perfil'),
  ];

  @override
  void initState() {
    super.initState();
    // Atualiza a posição do dono ao abrir o app (usada no Descobrir e nos parques).
    WidgetsBinding.instance.addPostFrameCallback((_) => updateMyLocation(context));
  }

  Widget _page() => switch (_tab) {
    0 => const FeedScreen(),
    1 => const DiscoverScreen(),
    2 => const MatchesScreen(),
    3 => const PlacesScreen(),
    _ => const ProfileScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 700;
    if (isTablet) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              labelType: NavigationRailLabelType.all,
              leading: const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.pets, size: 36)),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _page()),
          ],
        ),
      );
    }
    return Scaffold(
      body: _page(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          for (final d in _destinations) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
        ],
      ),
    );
  }
}
