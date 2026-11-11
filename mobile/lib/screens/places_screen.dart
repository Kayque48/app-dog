import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../models.dart';
import '../widgets.dart';

/// Parques e pontos de encontro próximos (os 5 mais perto).
class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key, this.embedded = false});

  /// Dentro da aba "Rolês" a tela não mostra a própria barra de título.
  final bool embedded;

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  List<Map<String, dynamic>>? _places;
  String? _error;
  Position? _pos;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _pos = await updateMyLocation(context);
    try {
      final q = _pos == null ? '' : '?lat=${_pos!.latitude}&lng=${_pos!.longitude}';
      final data = List<Map<String, dynamic>>.from(await Api.instance.get('/places$q'));
      if (!mounted) return;
      setState(() {
        _places = data;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _addPlace() async {
    final pos = _pos;
    if (pos == null) {
      showMessage(context, 'Ative a localização: o ponto será salvo onde você está agora.');
      return;
    }
    final name = TextEditingController();
    String kind = 'ponto_encontro';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Sugerir ponto de encontro'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('O ponto será marcado no local onde você está agora.'),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nome do local'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: kind,
                items: [for (final e in placeKinds.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setLocal(() => kind = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await Api.instance.post('/places', {'name': name.text, 'kind': kind, 'lat': pos.latitude, 'lng': pos.longitude});
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _openMap(Map<String, dynamic> p) => launchUrl(
    Uri.parse('https://www.google.com/maps/search/?api=1&query=${p['lat']},${p['lng']}'),
    mode: LaunchMode.externalApplication,
  );

  @override
  Widget build(BuildContext context) {
    final places = _places;
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('Parques e pontos de encontro')),
      floatingActionButton: FloatingActionButton(onPressed: _addPlace, child: const Icon(Icons.add_location_alt)),
      body: _error != null
          ? EmptyState(
              icon: Icons.location_off,
              text: _error!,
              action: OutlinedButton(onPressed: _load, child: const Text('Tentar de novo')),
            )
          : places == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Constrained(
                child: ListView(
                  children: [
                    for (final p in places)
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: Icon(p['kind'] == 'parque' ? Icons.park : Icons.place, size: 36),
                          title: Text(p['name']),
                          subtitle: Text(
                            '${placeKinds[p['kind']]} • ${formatDistance(p['distance_m'])}\n${p['address']}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.map),
                          onTap: () => _openMap(p),
                        ),
                      ),
                    const AdBanner(),
                  ],
                ),
              ),
            ),
    );
  }
}
