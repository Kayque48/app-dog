import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart' show display, likeYellow;
import '../models.dart';
import '../widgets.dart';
import 'event_detail_screen.dart';
import 'places_screen.dart';
import 'services_screen.dart';
import 'shop_screen.dart';

/// Aba "Explorar": eventos, serviços (veterinários, banho e tosa...), loja e parques.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Explorar', style: display(Theme.of(context).textTheme.displaySmall)),
          toolbarHeight: 72,
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.celebration), text: 'Eventos'),
              Tab(icon: Icon(Icons.medical_services), text: 'Serviços'),
              Tab(icon: Icon(Icons.storefront), text: 'Loja'),
              Tab(icon: Icon(Icons.park), text: 'Parques'),
            ],
          ),
        ),
        body: const TabBarView(children: [EventsList(), ServicesScreen(), ShopScreen(), PlacesScreen(embedded: true)]),
      ),
    );
  }
}

class EventsList extends StatefulWidget {
  const EventsList({super.key});

  @override
  State<EventsList> createState() => _EventsListState();
}

class _EventsListState extends State<EventsList> {
  List<Map<String, dynamic>>? _events;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = List<Map<String, dynamic>>.from(await Api.instance.get('/events'));
      if (mounted) setState(() => _events = data);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _rsvp(Map<String, dynamic> e, String status) async {
    final next = e['my_rsvp'] == status ? null : status;
    setState(() {
      if (e['my_rsvp'] == 'going') e['going']--;
      if (e['my_rsvp'] == 'maybe') e['maybe']--;
      if (next == 'going') e['going']++;
      if (next == 'maybe') e['maybe']++;
      e['my_rsvp'] = next;
    });
    if (next == 'going') showMessage(context, 'Bora! Você vai no ${e['title']} 🎉');
    try {
      await Api.instance.post('/events/${e['id']}/rsvp', {'status': next});
    } catch (err) {
      if (mounted) showError(context, err);
      _load();
    }
  }

  Future<void> _open(Map<String, dynamic> e) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: e['id'])));
    _load();
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const NewEventScreen()));
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final events = _events;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Criar evento'),
      ),
      body: events == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: events.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        EmptyState(icon: Icons.event_busy, text: 'Nenhum evento por aqui. Que tal criar um?'),
                      ],
                    )
                  : Constrained(
                      maxWidth: 720,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                        itemCount: events.length,
                        itemBuilder: (context, i) => EventCard(
                          event: events[i],
                          index: i,
                          onTap: () => _open(events[i]),
                          onRsvp: (s) => _rsvp(events[i], s),
                        ),
                      ),
                    ),
            ),
    );
  }
}

/// Cartão de evento: capa com forma variada, data em "cookie" amarelo e botões Vou / Talvez.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, required this.index, required this.onTap, required this.onRsvp});
  final Map<String, dynamic> event;
  final int index;
  final VoidCallback onTap;
  final ValueChanged<String> onRsvp;

  static const _radii = [
    BorderRadius.only(
      topLeft: Radius.circular(40),
      topRight: Radius.circular(40),
      bottomRight: Radius.circular(80),
      bottomLeft: Radius.circular(12),
    ),
    BorderRadius.only(
      topLeft: Radius.circular(40),
      topRight: Radius.circular(40),
      bottomRight: Radius.circular(12),
      bottomLeft: Radius.circular(80),
    ),
    BorderRadius.all(Radius.circular(40)),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final e = event;
    final d = EventDate(e['starts_at']);
    final kind = eventKinds[e['kind']]!;
    final rsvp = e['my_rsvp'];
    String rules = '';
    if (e['entry_sex'] == 'femea') rules = ' · só fêmeas';
    if (e['entry_sex'] == 'macho') rules = ' · só machos';
    if (e['entry_breed'] != null) rules += ' · só ${e['entry_breed']}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(40)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onTap,
              child: ClipRRect(
                borderRadius: _radii[index % 3],
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: scheme.primaryContainer,
                        child: Icon(kind.$2, size: 72, color: scheme.onPrimaryContainer),
                      ),
                      if (e['cover_url'] != null)
                        Image.network(
                          Api.imageUrl(e['cover_url'])!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(),
                        ),
                      Positioned(left: 14, top: 14, child: DateBadge(date: d)),
                      if (d.soon)
                        Positioned(
                          right: 14,
                          top: 20,
                          child: Chip(
                            backgroundColor: scheme.inverseSurface,
                            label: Text(
                              '🔥 ${d.countdown}',
                              style: TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Chip(
                        backgroundColor: scheme.primaryContainer,
                        avatar: Icon(kind.$2, size: 18),
                        label: Text(kind.$1),
                      ),
                      if (e['has_contest'] == true)
                        Chip(
                          backgroundColor: scheme.secondaryContainer,
                          avatar: Icon(Icons.emoji_events, size: 18, color: scheme.onSecondaryContainer),
                          label: Text('Concurso$rules'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onTap,
                    child: Text(e['title'], style: display(Theme.of(context).textTheme.headlineMedium)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${d.time} · ${d.countdown} · ${e['place_name']}'
                    '${e['distance_m'] != null ? ' · ${formatDistance(e['distance_m'])}' : ''}',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  Text(
                    '${e['going']} vão · ${e['maybe']} talvez${e['has_contest'] == true ? ' · ${e['entries']} na disputa' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  RsvpButtons(status: rsvp, onChanged: onRsvp),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Data do evento num "cookie" amarelo.
class DateBadge extends StatelessWidget {
  const DateBadge({super.key, required this.date, this.size = 80});
  final EventDate date;
  final double size;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF231B00);
    return Shaped(
      shape: Shapes.cookie12,
      size: size,
      child: ColoredBox(
        color: likeYellow,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              date.week,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: ink, letterSpacing: 1),
            ),
            Text(
              date.day,
              style: display(TextStyle(fontSize: size * 0.34, color: ink)),
            ),
            Text(
              date.month,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: ink, letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botões "Vou" / "Talvez" em pílula; o escolhido vira um quadrado arredondado (M3 Expressive).
class RsvpButtons extends StatelessWidget {
  const RsvpButtons({super.key, required this.status, required this.onChanged});
  final String? status;
  final ValueChanged<String> onChanged;

  Widget _button(BuildContext context, String value, IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    final on = status == value;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        height: 56,
        decoration: BoxDecoration(
          color: on ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(on ? 16 : 28),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => onChanged(value),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: on ? scheme.onPrimary : scheme.onSurface),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: on ? scheme.onPrimary : scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _button(context, 'going', Icons.music_note, 'Vou'),
      const SizedBox(width: 10),
      _button(context, 'maybe', Icons.help_outline, 'Talvez'),
    ],
  );
}

/// Criar um evento (marcado na localização atual do dono).
class NewEventScreen extends StatefulWidget {
  const NewEventScreen({super.key});

  @override
  State<NewEventScreen> createState() => _NewEventScreenState();
}

class _NewEventScreenState extends State<NewEventScreen> {
  final _title = TextEditingController();
  final _place = TextEditingController();
  final _address = TextEditingController();
  final _description = TextEditingController();
  final _breed = TextEditingController();
  String _kind = 'festa';
  DateTime? _when;
  bool _contest = false;
  String? _sex;
  bool _saving = false;

  Future<void> _pickWhen() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      initialDate: now,
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 15, minute: 0));
    if (time == null) return;
    setState(() => _when = DateTime(day.year, day.month, day.day, time.hour, time.minute));
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _place.text.trim().isEmpty || _when == null) {
      showMessage(context, 'Preencha nome, local e quando');
      return;
    }
    setState(() => _saving = true);
    try {
      final pos = await updateMyLocation(context);
      final me = await Api.instance.get('/me');
      final lat = pos?.latitude ?? me['lat'];
      final lng = pos?.longitude ?? me['lng'];
      if (lat == null) throw 'Ative a localização: o evento é marcado onde você está';
      final w = _when!;
      await Api.instance.post('/events', {
        'title': _title.text,
        'description': _description.text,
        'kind': _kind,
        'place_name': _place.text,
        'address': _address.text,
        'lat': lat,
        'lng': lng,
        'starts_at': '${isoDate(w)} ${w.hour.toString().padLeft(2, '0')}:${w.minute.toString().padLeft(2, '0')}',
        'has_contest': _contest,
        'entry_sex': _contest ? _sex : null,
        'entry_breed': _contest && _breed.text.trim().isNotEmpty ? _breed.text : null,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo evento')),
      body: Constrained(
        maxWidth: 520,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Nome (ex.: Desfile de Cadelas)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                for (final k in eventKinds.entries)
                  DropdownMenuItem(
                    value: k.key,
                    child: Row(children: [Icon(k.value.$2), const SizedBox(width: 8), Text(k.value.$1)]),
                  ),
              ],
              onChanged: (v) => setState(() => _kind = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _place,
              decoration: const InputDecoration(labelText: 'Local'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Endereço / referência'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickWhen,
              icon: const Icon(Icons.event),
              label: Text(
                _when == null
                    ? 'Quando?'
                    : '${formatDate(isoDate(_when!))} às ${TimeOfDay.fromDateTime(_when!).format(context)}',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descrição'),
            ),
            SwitchListTile(
              title: const Text('Tem concurso com votação'),
              value: _contest,
              onChanged: (v) => setState(() => _contest = v),
            ),
            if (_contest) ...[
              SegmentedButton<String?>(
                segments: const [
                  ButtonSegment(value: null, label: Text('Todos')),
                  ButtonSegment(value: 'femea', label: Text('Só fêmeas')),
                  ButtonSegment(value: 'macho', label: Text('Só machos')),
                ],
                selected: {_sex},
                onSelectionChanged: (s) => setState(() => _sex = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _breed,
                decoration: const InputDecoration(labelText: 'Só a raça (opcional)'),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.celebration),
              label: Text(_saving ? 'Criando...' : 'Criar evento'),
            ),
          ],
        ),
      ),
    );
  }
}
