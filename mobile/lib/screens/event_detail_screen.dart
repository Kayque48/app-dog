import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../main.dart' show display, likeYellow;
import '../models.dart';
import '../widgets.dart';
import 'dog_detail_screen.dart';
import 'events_screen.dart';

/// Evento: capa, presença, concurso com pódio e votação, inscrição e quem vai.
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});
  final int eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Map<String, dynamic>? _data;
  List<Dog> _myDogs = [];
  int? _entryDog;

  @override
  void initState() {
    super.initState();
    _load();
    Api.instance
        .get('/dogs/mine')
        .then((data) {
          final dogs = (data as List).map((j) => Dog.fromJson(j)).where((d) => !d.removed).toList();
          if (mounted) {
            setState(() {
              _myDogs = dogs;
              _entryDog = dogs.isEmpty ? null : dogs.first.id;
            });
          }
        })
        .catchError((_) {});
  }

  Future<void> _load() async {
    try {
      final data = await Api.instance.get('/events/${widget.eventId}');
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _rsvp(String status) async {
    final current = _data!['event']['my_rsvp'];
    try {
      await Api.instance.post('/events/${widget.eventId}/rsvp', {'status': current == status ? null : status});
      if (status == 'going' && current != 'going' && mounted) showMessage(context, 'Bora! Presença confirmada 🎉');
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _vote(Map<String, dynamic> entry) async {
    try {
      await Api.instance.post('/events/${widget.eventId}/vote', {'entry_id': entry['id']});
      if (mounted) showMessage(context, 'Voto em ${entry['dog_name']}! 🗳️');
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _enter() async {
    try {
      await Api.instance.post('/events/${widget.eventId}/entries', {'dog_id': _entryDog});
      if (mounted) showMessage(context, 'Inscrição feita! Agora é pedir voto pra galera 📣');
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final e = data['event'];
    final d = EventDate(e['starts_at']);
    final kind = eventKinds[e['kind']]!;
    final entries = List<Map<String, dynamic>>.from(data['entries']);
    final attendees = List<Map<String, dynamic>>.from(data['attendees']);
    final totalVotes = entries.fold<int>(0, (s, x) => s + (x['votes'] as int));
    final mine = _myDogs.map((x) => x.id).toSet();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(80),
                  bottomLeft: Radius.circular(24),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: scheme.primaryContainer,
                      child: Icon(kind.$2, size: 100, color: scheme.onPrimaryContainer),
                    ),
                    if (e['cover_url'] != null)
                      Image.network(
                        Api.imageUrl(e['cover_url'])!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(),
                      ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.center,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, const Color(0xFF000A3C).withValues(alpha: 0.8)],
                        ),
                      ),
                    ),
                    Positioned(right: 20, top: 90, child: DateBadge(date: d, size: 96)),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Chip(
                            backgroundColor: likeYellow,
                            avatar: Icon(kind.$2, size: 18, color: const Color(0xFF231B00)),
                            label: Text(kind.$1, style: const TextStyle(color: Color(0xFF231B00))),
                          ),
                          Text(e['title'], style: display(t.headlineLarge)?.copyWith(color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Constrained(
              maxWidth: 720,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Fact(
                      icon: Icons.schedule,
                      title: '${d.time} · ${d.countdown}',
                      subtitle: '${d.week} ${d.day} ${d.month}',
                    ),
                    _Fact(
                      icon: Icons.location_on,
                      title: e['place_name'],
                      subtitle:
                          '${e['address']}${e['distance_m'] != null ? ' · ${formatDistance(e['distance_m'])}' : ''}',
                      onTap: () => launchUrl(
                        Uri.parse('https://www.google.com/maps/search/?api=1&query=${e['lat']},${e['lng']}'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                    _Fact(icon: Icons.groups, title: '${e['going']} vão', subtitle: '${e['maybe']} talvez'),
                    if ((e['description'] as String).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(e['description'], style: t.bodyLarge),
                      ),
                    RsvpButtons(status: e['my_rsvp'], onChanged: _rsvp),
                    if (e['has_contest'] == true) ...[
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          const Icon(Icons.emoji_events, color: likeYellow, size: 36),
                          const SizedBox(width: 8),
                          Text('Concurso', style: display(t.headlineMedium)),
                        ],
                      ),
                      Text(
                        '${e['entry_sex'] == 'femea'
                            ? 'Só fêmeas. '
                            : e['entry_sex'] == 'macho'
                            ? 'Só machos. '
                            : ''}'
                        '${e['entry_breed'] != null ? 'Só ${e['entry_breed']}. ' : ''}'
                        'Um voto por pessoa, sem votar no próprio cão. $totalVotes votos até agora.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      if (entries.isNotEmpty) _Podium(entries: entries.take(3).toList()),
                      for (var i = 0; i < entries.length; i++)
                        _EntryTile(
                          entry: entries[i],
                          position: i + 1,
                          totalVotes: totalVotes,
                          voted: data['my_vote'] == entries[i]['id'],
                          isMine: mine.contains(entries[i]['dog_id']),
                          onVote: () => _vote(entries[i]),
                        ),
                      if (entries.isEmpty)
                        const EmptyState(icon: Icons.emoji_events, text: 'Ninguém inscrito ainda. Seja o primeiro!'),
                      if (_myDogs.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(28),
                              topRight: Radius.circular(80),
                              bottomLeft: Radius.circular(80),
                              bottomRight: Radius.circular(28),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bota seu cão na disputa!',
                                style: display(t.headlineSmall)?.copyWith(color: scheme.onSecondaryContainer),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                initialValue: _entryDog,
                                items: [for (final x in _myDogs) DropdownMenuItem(value: x.id, child: Text(x.name))],
                                onChanged: (v) => setState(() => _entryDog = v),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: scheme.onSecondaryContainer,
                                  foregroundColor: scheme.secondaryContainer,
                                ),
                                onPressed: _enter,
                                icon: const Icon(Icons.add_circle),
                                label: const Text('Inscrever'),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 28),
                    Text('Quem vai (${attendees.length})', style: display(t.titleLarge)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (var i = 0; i < attendees.length; i++)
                          GestureDetector(
                            onTap: () => Navigator.of(context)
                                .push(MaterialPageRoute(builder: (_) => DogDetailScreen(dogId: attendees[i]['id']))),
                            child: Column(
                              children: [
                                ShapedDog(photoUrl: attendees[i]['photo_url'], shape: Shapes.all[i % 4], size: 64),
                                Text(attendees[i]['name'], style: t.labelSmall),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.title, required this.subtitle, this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.filled(
      color: scheme.surfaceContainer,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: scheme.primary, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: onTap == null ? null : const Icon(Icons.map),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.entries});
  final List<Map<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const medals = ['🥇', '🥈', '🥉'];
    final colors = [likeYellow, scheme.primary, scheme.tertiary];
    final ink = [const Color(0xFF231B00), scheme.onPrimary, Colors.white];
    final heights = [120.0, 84.0, 60.0];
    // ordem visual: 2º, 1º, 3º
    final order = [1, 0, 2].where((i) => i < entries.length);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final place in order)
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 500 + place * 150),
                curve: Curves.easeOutBack,
                builder: (context, v, child) => Transform.translate(
                  offset: Offset(0, 40 * (1 - v)),
                  child: Opacity(opacity: v.clamp(0, 1), child: child),
                ),
                child: Column(
                  children: [
                    Text(medals[place], style: const TextStyle(fontSize: 30)),
                    ShapedDog(
                      photoUrl: entries[place]['dog_photo_url'],
                      shape: place == 0 ? Shapes.cookie9 : Shapes.flower,
                      size: place == 0 ? 96 : 72,
                    ),
                    Text(entries[place]['dog_name'], style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text('${entries[place]['votes']} votos', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Container(
                      height: heights[place],
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors[place],
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24), bottom: Radius.circular(8)),
                      ),
                      child: Text('${place + 1}º', style: display(TextStyle(fontSize: 28, color: ink[place]))),
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

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.position,
    required this.totalVotes,
    required this.voted,
    required this.isMine,
    required this.onVote,
  });
  final Map<String, dynamic> entry;
  final int position;
  final int totalVotes;
  final bool voted;
  final bool isMine;
  final VoidCallback onVote;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final votes = entry['votes'] as int;
    final pct = totalVotes == 0 ? 0.0 : votes / totalVotes;
    final fg = voted ? scheme.onSecondaryContainer : scheme.onSurface;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: voted ? scheme.secondaryContainer : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$position',
              textAlign: TextAlign.center,
              style: display(TextStyle(fontSize: 22, color: fg)),
            ),
          ),
          const SizedBox(width: 8),
          ShapedDog(photoUrl: entry['dog_photo_url'], shape: Shapes.cookie12, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry['dog_name'],
                  style: TextStyle(fontWeight: FontWeight.w900, color: fg),
                ),
                Text('${entry['dog_breed']} · ${entry['owner_name']}', style: TextStyle(fontSize: 12, color: fg)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: pct),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 10),
                  ),
                ),
                Text(
                  '$votes voto${votes == 1 ? '' : 's'} · ${(pct * 100).round()}%',
                  style: TextStyle(fontSize: 12, color: fg),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isMine)
            const Chip(label: Text('Seu cão'))
          else
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                backgroundColor: voted ? scheme.onSecondaryContainer : scheme.primary,
                foregroundColor: voted ? scheme.secondaryContainer : scheme.onPrimary,
              ),
              onPressed: onVote,
              icon: Icon(voted ? Icons.how_to_vote : Icons.how_to_vote_outlined),
              label: Text(voted ? 'Seu voto' : 'Votar'),
            ),
        ],
      ),
    );
  }
}
