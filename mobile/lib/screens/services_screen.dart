import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../main.dart' show display;
import '../models.dart';
import '../widgets.dart';

/// Serviços: veterinários, banho e tosa, adestradores, passeadores, hotéis, criadores e adoção.
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  String _kind = '';
  List<Map<String, dynamic>>? _providers;
  List<Map<String, dynamic>> _appointments = [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadAppointments();
  }

  Future<void> _load() async {
    try {
      final data = List<Map<String, dynamic>>.from(await Api.instance.get('/providers?kind=$_kind'));
      if (mounted) setState(() => _providers = data);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _loadAppointments() async {
    try {
      final data = List<Map<String, dynamic>>.from(await Api.instance.get('/appointments'));
      final today = isoDate(DateTime.now());
      if (mounted) {
        setState(
          () => _appointments = data
              .where((a) => a['status'] != 'cancelado' && (a['date_time'] as String).compareTo(today) >= 0)
              .toList(),
        );
      }
    } catch (_) {}
  }

  Future<void> _open(Map<String, dynamic> p) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ProviderSheet(provider: p),
    );
    _loadAppointments();
  }

  Future<void> _cancel(Map<String, dynamic> a) async {
    try {
      await Api.instance.post('/appointments/${a['id']}/cancel');
      _loadAppointments();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final providers = _providers;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await Navigator.of(context)
              .push<bool>(MaterialPageRoute(builder: (_) => const NewProviderScreen()));
          if (ok == true) _load();
        },
        icon: const Icon(Icons.add_business),
        label: const Text('Meu negócio'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _load();
          await _loadAppointments();
        },
        child: Constrained(
          maxWidth: 720,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            children: [
              if (_appointments.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(32)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meus agendamentos',
                        style: display(Theme.of(context).textTheme.titleLarge)
                            ?.copyWith(color: scheme.onSecondaryContainer),
                      ),
                      for (final a in _appointments)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: scheme.onSecondaryContainer,
                            foregroundColor: scheme.secondaryContainer,
                            child: Text((a['date_time'] as String).substring(8, 10)),
                          ),
                          title: Text('${a['service']} · ${a['dog_name']}'),
                          subtitle: Text(
                            '${formatDate(a['date_time'])} ${(a['date_time'] as String).substring(11)} · ${a['provider_name']}\n'
                            '${a['status'] == 'confirmado' ? 'Confirmado ✅' : 'Aguardando confirmação'}',
                          ),
                          isThreeLine: true,
                          trailing: TextButton(onPressed: () => _cancel(a), child: const Text('Cancelar')),
                        ),
                    ],
                  ),
                ),
              // tipos em formas expressivas
              SizedBox(
                height: 104,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _KindButton(
                      label: 'Todos',
                      icon: Icons.apps,
                      shape: Shapes.cookie9,
                      on: _kind == '',
                      onTap: () {
                        _kind = '';
                        _load();
                      },
                    ),
                    for (final (i, e) in providerKinds.entries.indexed)
                      _KindButton(
                        label: e.value.$1,
                        icon: e.value.$2,
                        shape: Shapes.all[(i + 1) % 4],
                        on: _kind == e.key,
                        onTap: () {
                          _kind = e.key;
                          _load();
                        },
                      ),
                  ],
                ),
              ),
              if (providers == null)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (providers != null && providers.isEmpty)
                const EmptyState(icon: Icons.search_off, text: 'Nenhum cadastro aqui ainda.'),
              for (final (i, p) in (providers ?? []).indexed)
                Card.filled(
                  color: scheme.surfaceContainerLow,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                  child: InkWell(
                    onTap: () => _open(p),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Shaped(
                            shape: Shapes.all[i % 4],
                            size: 64,
                            child: ColoredBox(
                              color: scheme.primaryContainer,
                              child: Icon(providerKinds[p['kind']]!.$2, size: 32, color: scheme.onPrimaryContainer),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(p['name'], style: display(Theme.of(context).textTheme.titleLarge)),
                                    ),
                                    if (p['verified'] == true) ...[
                                      const SizedBox(width: 4),
                                      Icon(Icons.verified, size: 20, color: scheme.primary),
                                    ],
                                  ],
                                ),
                                Text(
                                  '${providerKinds[p['kind']]!.$1}'
                                  '${p['distance_m'] != null ? ' · ${formatDistance(p['distance_m'])}' : ''}',
                                  style: TextStyle(color: scheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 4),
                                Text(p['description']),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindButton extends StatelessWidget {
  const _KindButton({
    required this.label,
    required this.icon,
    required this.shape,
    required this.on,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final ShapeBorder shape;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 88,
        child: Column(
          children: [
            AnimatedRotation(
              turns: on ? 0.05 : 0,
              duration: const Duration(milliseconds: 300),
              child: Shaped(
                shape: shape,
                size: 64,
                child: ColoredBox(
                  color: on ? scheme.primary : scheme.surfaceContainerHigh,
                  child: Icon(icon, color: on ? scheme.onPrimary : scheme.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(fontSize: 12, fontWeight: on ? FontWeight.w800 : FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detalhe do profissional: contato e agendamento.
class ProviderSheet extends StatefulWidget {
  const ProviderSheet({super.key, required this.provider});
  final Map<String, dynamic> provider;

  @override
  State<ProviderSheet> createState() => _ProviderSheetState();
}

class _ProviderSheetState extends State<ProviderSheet> {
  List<Dog> _dogs = [];
  int? _dogId;
  String? _service;
  DateTime? _when;
  final _notes = TextEditingController();

  List<String> get _services =>
      (widget.provider['services'] as String).split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  @override
  void initState() {
    super.initState();
    _service = _services.firstOrNull;
    Api.instance
        .get('/dogs/mine')
        .then((data) {
          final dogs = (data as List).map((j) => Dog.fromJson(j)).where((d) => !d.removed).toList();
          if (mounted) {
            setState(() {
              _dogs = dogs;
              _dogId = dogs.firstOrNull?.id;
            });
          }
        })
        .catchError((_) {});
  }

  Future<void> _pickWhen() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
      initialDate: now,
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
    if (time == null) return;
    setState(() => _when = DateTime(day.year, day.month, day.day, time.hour, time.minute));
  }

  Future<void> _book() async {
    if (_dogId == null || _service == null || _when == null) {
      showMessage(context, 'Escolha o cão, o serviço e o horário');
      return;
    }
    final w = _when!;
    try {
      final r = await Api.instance.post('/appointments', {
        'provider_id': widget.provider['id'],
        'dog_id': _dogId,
        'service': _service,
        'date_time': '${isoDate(w)} ${w.hour.toString().padLeft(2, '0')}:${w.minute.toString().padLeft(2, '0')}',
        'notes': _notes.text,
      });
      if (!mounted) return;
      Navigator.pop(context);
      showMessage(context, r['message']);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = widget.provider;
    final phone = p['phone'] as String;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Shaped(
                shape: Shapes.flower,
                size: 88,
                child: ColoredBox(
                  color: scheme.primaryContainer,
                  child: Icon(providerKinds[p['kind']]!.$2, size: 44, color: scheme.onPrimaryContainer),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(p['name'], textAlign: TextAlign.center, style: display(Theme.of(context).textTheme.headlineSmall)),
            if (p['verified'] == true)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified, size: 18, color: scheme.primary),
                  const Text(' Verificado pela moderação'),
                ],
              ),
            Text(
              p['address'],
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(p['description'], textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                  icon: const Icon(Icons.call),
                  label: const Text('Ligar'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => launchUrl(
                    Uri.parse('https://wa.me/55$phone?text=${Uri.encodeComponent('Oi! Vi vocês no All Love 🐾')}'),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.chat),
                  label: const Text('WhatsApp'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => launchUrl(
                    Uri.parse('https://www.google.com/maps/search/?api=1&query=${p['lat']},${p['lng']}'),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.map),
                  label: const Text('Mapa'),
                ),
              ],
            ),
            if (_dogs.isNotEmpty && p['kind'] != 'adocao' && _services.isNotEmpty) ...[
              const Divider(height: 32),
              Text('Agendar', style: display(Theme.of(context).textTheme.titleLarge)),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _dogId,
                decoration: const InputDecoration(labelText: 'Cão'),
                items: [for (final d in _dogs) DropdownMenuItem(value: d.id, child: Text(d.name))],
                onChanged: (v) => setState(() => _dogId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _service,
                decoration: const InputDecoration(labelText: 'Serviço'),
                items: [for (final s in _services) DropdownMenuItem(value: s, child: Text(s))],
                onChanged: (v) => setState(() => _service = v),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickWhen,
                icon: const Icon(Icons.event),
                label: Text(
                  _when == null
                      ? 'Escolher horário'
                      : '${formatDate(isoDate(_when!))} às ${TimeOfDay.fromDateTime(_when!).format(context)}',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Observações'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _book,
                icon: const Icon(Icons.event_available),
                label: const Text('Pedir horário'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Cadastro de profissional ou estabelecimento (fica pendente até a moderação verificar).
class NewProviderScreen extends StatefulWidget {
  const NewProviderScreen({super.key});

  @override
  State<NewProviderScreen> createState() => _NewProviderScreenState();
}

class _NewProviderScreenState extends State<NewProviderScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _services = TextEditingController();
  final _description = TextEditingController();
  String _kind = 'veterinario';
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final pos = await updateMyLocation(context);
      final me = await Api.instance.get('/me');
      final lat = pos?.latitude ?? me['lat'];
      final lng = pos?.longitude ?? me['lng'];
      if (lat == null) throw 'Ative a localização: o endereço é marcado onde você está';
      final r = await Api.instance.post('/providers', {
        'name': _name.text,
        'kind': _kind,
        'phone': _phone.text,
        'address': _address.text,
        'services': _services.text,
        'description': _description.text,
        'lat': lat,
        'lng': lng,
      });
      if (!mounted) return;
      showMessage(context, r['message']);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastrar meu negócio')),
      body: Constrained(
        maxWidth: 520,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                for (final e in providerKinds.entries)
                  DropdownMenuItem(
                    value: e.key,
                    child: Row(children: [Icon(e.value.$2), const SizedBox(width: 8), Text(e.value.$1)]),
                  ),
              ],
              onChanged: (v) => setState(() => _kind = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefone / WhatsApp com DDD'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Endereço'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _services,
              decoration: const InputDecoration(labelText: 'Serviços (separe por vírgula)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descrição'),
            ),
            const SizedBox(height: 8),
            const Text('O selo de verificado aparece depois da análise da moderação.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.send),
              label: Text(_saving ? 'Enviando...' : 'Enviar cadastro'),
            ),
          ],
        ),
      ),
    );
  }
}
