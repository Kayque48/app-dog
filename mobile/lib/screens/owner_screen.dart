import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../widgets.dart';
import 'dog_detail_screen.dart';

/// Perfil público do dono: os cães que ele tem e já teve, e incidentes confirmados.
class OwnerScreen extends StatelessWidget {
  const OwnerScreen({super.key, required this.userId});
  final int userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dono(a)')),
      body: FutureBuilder(
        future: Api.instance.get('/users/$userId'),
        builder: (context, snap) {
          if (snap.hasError) return EmptyState(icon: Icons.error, text: snap.error.toString());
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final u = snap.data as Map<String, dynamic>;
          final incidents = u['confirmed_incidents'] as int;
          return Constrained(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(u['first_name'], style: Theme.of(context).textTheme.titleLarge),
                subtitle: Text('${u['city']} • no All Love desde ${formatDate(u['member_since'])}'),
              ),
              if (u['banned'] == true)
                const Card(color: Color(0xFFFFEBEE), child: ListTile(leading: Icon(Icons.block), title: Text('Conta bloqueada'))),
              ListTile(
                leading: Icon(incidents == 0 ? Icons.verified_user : Icons.warning, color: incidents == 0 ? Colors.green : Colors.red),
                title: Text(incidents == 0 ? 'Nenhum incidente confirmado' : '$incidents incidente(s) confirmado(s)'),
              ),
              const Divider(),
              const Text('Cães deste dono', style: TextStyle(fontWeight: FontWeight.bold)),
              for (final d in u['dogs'])
                ListTile(
                  leading: DogAvatar(photoUrl: d['photo_url']),
                  title: Text('${d['name']} (${d['breed']})'),
                  subtitle: Text(d['current']
                      ? 'Desde ${formatDate(d['since'])}'
                      : 'De ${formatDate(d['since'])} até ${formatDate(d['until'])}'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DogDetailScreen(dogId: d['id']))),
                ),
            ]),
          );
        },
      ),
    );
  }
}
