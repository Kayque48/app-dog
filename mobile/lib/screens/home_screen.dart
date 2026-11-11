import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';
import 'discover_screen.dart';
import 'feed_screen.dart';
import 'matches_screen.dart';
import 'events_screen.dart';
import 'profile_screen.dart';

/// Tela principal com as 5 abas. Em tablets usa uma barra lateral.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  int _requests = 0; // pedidos de encontro esperando resposta (badge)
  Timer? _timer;

  static const _destinations = [
    (Icons.photo_library_outlined, Icons.photo_library, 'Feed'),
    (Icons.style_outlined, Icons.style, 'Descobrir'),
    (Icons.favorite_border, Icons.favorite, 'Encontros'),
    (Icons.explore_outlined, Icons.explore, 'Explorar'),
    (Icons.person_outline, Icons.person, 'Perfil'),
  ];

  @override
  void initState() {
    super.initState();
    // Atualiza a posição do dono ao abrir o app (usada no Descobrir e nos parques).
    WidgetsBinding.instance.addPostFrameCallback((_) => updateMyLocation(context));
    _loadCounts();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _loadCounts());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    try {
      final items = await Api.instance.get('/matches') as List;
      final n = items.where((m) => m['status'] == 'pending' && m['direction'] == 'incoming').length;
      if (mounted) setState(() => _requests = n);
    } catch (_) {}
  }

  void _select(int i) {
    setState(() => _tab = i);
    _loadCounts();
  }

  Widget _page() => switch (_tab) {
    0 => FeedScreen(onOpenTab: _select),
    1 => const DiscoverScreen(),
    2 => const MatchesScreen(),
    3 => const ExploreScreen(),
    _ => const ProfileScreen(),
  };

  Widget _icon(int index, IconData icon) => index == 2 && _requests > 0
      ? Badge(
          label: Text('$_requests'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          textColor: Theme.of(context).colorScheme.onPrimary,
          child: Icon(icon),
        )
      : Icon(icon);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isTablet = MediaQuery.sizeOf(context).width >= 700;
    if (isTablet) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _tab,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.all(12),
                child: Shaped(
                  shape: Shapes.cookie9,
                  size: 56,
                  child: ColoredBox(
                    color: scheme.secondaryContainer,
                    child: Icon(Icons.pets, size: 30, color: scheme.onSecondaryContainer),
                  ),
                ),
              ),
              destinations: [
                for (var i = 0; i < _destinations.length; i++)
                  NavigationRailDestination(
                    icon: _icon(i, _destinations[i].$1),
                    selectedIcon: _icon(i, _destinations[i].$2),
                    label: Text(_destinations[i].$3),
                  ),
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
        onDestinationSelected: _select,
        destinations: [
          for (var i = 0; i < _destinations.length; i++)
            NavigationDestination(
              icon: _icon(i, _destinations[i].$1),
              selectedIcon: _icon(i, _destinations[i].$2),
              label: _destinations[i].$3,
            ),
        ],
      ),
    );
  }
}
