import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../widgets.dart';
import 'dog_detail_screen.dart';

/// Pedidos de encontro recebidos (aceitar ou recusar), enviados e combinados.
class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  List<Map<String, dynamic>>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = List<Map<String, dynamic>>.from(await Api.instance.get('/matches'));
      if (mounted) setState(() => _items = data);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _respond(Map<String, dynamic> m, bool accept) async {
    try {
      await Api.instance.post('/matches/${m['id']}/respond', {'accept': accept});
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Encontros')),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: items.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 120),
                      EmptyState(icon: Icons.favorite_border, text: 'Nenhum encontro ainda. Vá em Descobrir!'),
                    ])
                  : Constrained(
                      child: ListView(children: [
                        _section('Pedidos para você', items.where((m) => m['status'] == 'pending' && m['direction'] == 'incoming')),
                        _section('Encontros combinados', items.where((m) => m['status'] == 'accepted')),
                        _section('Aguardando resposta', items.where((m) => m['status'] == 'pending' && m['direction'] == 'outgoing')),
                      ]),
                    ),
            ),
    );
  }

  Widget _section(String title, Iterable<Map<String, dynamic>> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ),
      for (final m in list) _tile(m),
    ]);
  }

  Widget _tile(Map<String, dynamic> m) {
    final other = m['other_dog'];
    final owner = m['other_owner'];
    final phone = owner['phone'] as String?;
    final incomingPending = m['status'] == 'pending' && m['direction'] == 'incoming';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(children: [
        ListTile(
          leading: DogAvatar(photoUrl: other['photo_url']),
          title: Text('${other['name']} (${other['breed']})'),
          subtitle: Text('Com ${m['my_dog']['name']} • dono(a): ${owner['first_name']}'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DogDetailScreen(dogId: other['id']))),
        ),
        if (incomingPending)
          OverflowBar(children: [
            TextButton(onPressed: () => _respond(m, false), child: const Text('Recusar')),
            FilledButton(onPressed: () => _respond(m, true), child: const Text('Aceitar')),
          ]),
        if (phone != null)
          OverflowBar(children: [
            TextButton.icon(
              icon: const Icon(Icons.phone),
              label: Text(phone),
              onPressed: () => launchUrl(Uri.parse('tel:$phone')),
            ),
            TextButton.icon(
              icon: const Icon(Icons.chat),
              label: const Text('WhatsApp'),
              onPressed: () => launchUrl(Uri.parse('https://wa.me/55$phone'), mode: LaunchMode.externalApplication),
            ),
          ]),
      ]),
    );
  }
}
