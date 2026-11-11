import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../main.dart' show display, likeYellow;
import '../widgets.dart';
import 'dog_detail_screen.dart';

/// Descobrir: cães por perto (500 m por padrão). Arraste para a direita para
/// pedir um encontro ou para a esquerda para passar.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  List<Dog> _myDogs = [];
  Dog? _myDog;
  List<Dog> _cards = [];
  int _radius = 500;
  int _seen = 0; // quantos cartões já passaram
  String _goal = 'amizade'; // amizade | cruzamento
  bool _loading = true;
  String? _blocked; // mensagem quando o cão está bloqueado (vacinas) ou sem localização

  @override
  void initState() {
    super.initState();
    _loadMyDogs();
  }

  Future<void> _loadMyDogs() async {
    try {
      final data = await Api.instance.get('/dogs/mine');
      _myDogs = (data as List).map((j) => Dog.fromJson(j)).where((d) => !d.removed).toList();
      _myDog = _myDogs.isEmpty ? null : _myDogs.first;
      await _loadCards();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _loadCards() async {
    final dog = _myDog;
    if (dog == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _blocked = null;
    });
    try {
      final data = await Api.instance.get('/discover?dog_id=${dog.id}&radius_m=$_radius&goal=$_goal');
      _cards = (data as List).map((j) => Dog.fromJson(j)).toList();
    } on ApiException catch (e) {
      if (e.status == 400 || e.status == 403) {
        _blocked = e.message;
        _cards = [];
      } else if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _swipe(Dog other, bool liked) async {
    setState(() {
      _cards.remove(other);
      _seen++;
    });
    try {
      final r = await Api.instance.post('/swipes', {'from_dog_id': _myDog!.id, 'to_dog_id': other.id, 'liked': liked});
      if (!mounted) return;
      if (r['matched'] == true) {
        Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (_, _, _) => MatchScreen(mine: _myDog!, other: other),
            transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
          ),
        );
      } else if (liked) {
        showMessage(context, 'Pedido enviado! Agora é só esperar o dono de ${other.name} aceitar.');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Constrained(
          maxWidth: 520,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    Expanded(child: Text('Descobrir', style: display(Theme.of(context).textTheme.displaySmall))),
                    if (_cards.isNotEmpty)
                      Chip(
                        backgroundColor: scheme.secondaryContainer,
                        avatar: Icon(Icons.pets, color: scheme.onSecondaryContainer),
                        label: Text('${_cards.length} por perto'),
                      ),
                  ],
                ),
              ),
              if (_myDogs.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: DropdownButtonFormField<int>(
                    initialValue: _myDog?.id,
                    decoration: const InputDecoration(labelText: 'Procurar amigos para'),
                    items: [for (final d in _myDogs) DropdownMenuItem(value: d.id, child: Text(d.name))],
                    onChanged: (id) {
                      _myDog = _myDogs.firstWhere((d) => d.id == id);
                      _loadCards();
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'amizade', icon: Icon(Icons.diversity_1), label: Text('Amizade')),
                    ButtonSegment(value: 'cruzamento', icon: Icon(Icons.favorite), label: Text('Cruzamento')),
                  ],
                  selected: {_goal},
                  onSelectionChanged: (s) {
                    _goal = s.first;
                    _loadCards();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SegmentedButton<int>(
                  segments: [
                    for (final r in [500, 1000, 3000]) ButtonSegment(value: r, label: Text('Até ${formatDistance(r)}')),
                  ],
                  selected: {_radius},
                  onSelectionChanged: (s) {
                    _radius = s.first;
                    _loadCards();
                  },
                ),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_myDog == null) {
      return const EmptyState(icon: Icons.pets, text: 'Cadastre seu cão na aba Perfil para encontrar amigos.');
    }
    if (_blocked != null) {
      return EmptyState(
        icon: _blocked!.contains('localização') ? Icons.location_off : Icons.vaccines,
        text: _blocked!,
        action: FilledButton(
          onPressed: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DogDetailScreen(dogId: _myDog!.id)));
            if (mounted) await updateMyLocation(context);
            _loadCards();
          },
          child: Text(_blocked!.contains('localização') ? 'Tentar de novo' : 'Abrir carteira de vacinação'),
        ),
      );
    }
    if (_cards.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        text: _seen > 0
            ? 'Você viu $_seen ${_seen == 1 ? 'cão' : 'cães'}! Tente aumentar a distância.'
            : 'Nenhum cão novo por perto agora. Tente aumentar a distância.',
        action: FilledButton.icon(
          onPressed: () {
            _radius = 3000;
            _loadCards();
          },
          icon: const Icon(Icons.travel_explore),
          label: const Text('Procurar até 3 km'),
        ),
      );
    }
    final dog = _cards.first;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: Dismissible(
            key: ValueKey(dog.id),
            onDismissed: (dir) => _swipe(dog, dir == DismissDirection.startToEnd),
            background: _swipeHint('QUERO!', likeYellow, const Color(0xFF231B00), Alignment.centerLeft, -0.2),
            secondaryBackground: _swipeHint(
              'PASSA',
              scheme.inverseSurface,
              scheme.onInverseSurface,
              Alignment.centerRight,
              0.2,
            ),
            child: _DogCard(dog: dog, shape: Shapes.all[_seen % 4]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 64),
                    backgroundColor: scheme.inverseSurface,
                    foregroundColor: scheme.onInverseSurface,
                    textStyle: display(Theme.of(context).textTheme.titleLarge),
                  ),
                  onPressed: () => _swipe(dog, false),
                  icon: const Icon(Icons.close, size: 28),
                  label: const Text('Passa'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 64),
                    backgroundColor: likeYellow,
                    foregroundColor: const Color(0xFF231B00),
                    textStyle: display(Theme.of(context).textTheme.titleLarge),
                  ),
                  onPressed: () => _swipe(dog, true),
                  icon: const Icon(Icons.favorite, size: 28),
                  label: const Text('Quero!'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _swipeHint(String text, Color bg, Color fg, Alignment align, double angle) => Container(
    alignment: align,
    padding: const EdgeInsets.symmetric(horizontal: 32),
    child: Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Text(text, style: display(Theme.of(context).textTheme.headlineMedium)?.copyWith(color: fg)),
      ),
    ),
  );
}

class _DogCard extends StatelessWidget {
  const _DogCard({required this.dog, required this.shape});
  final Dog dog;
  final ShapeBorder shape;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
      color: scheme.surfaceContainerLow,
      elevation: 3,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DogDetailScreen(dogId: dog.id))),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: ShapedDog(photoUrl: dog.photoUrl, shape: shape, size: 260),
                ),
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Chip(
                    backgroundColor: scheme.secondaryContainer,
                    avatar: Icon(Icons.near_me, color: scheme.onSecondaryContainer),
                    label: Text(formatDistance(dog.distanceM ?? 0)),
                  ),
                ),
                if (dog.wantsToMeetYou)
                  Positioned(
                    right: -4,
                    top: 8,
                    child: Transform.rotate(
                      angle: 0.1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: const BoxDecoration(
                          color: likeYellow,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                            bottomLeft: Radius.circular(24),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                        child: const Text(
                          '💛 Quer te conhecer!',
                          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF231B00)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(dog.name, style: display(t.displayMedium)?.copyWith(color: scheme.primary)),
            Text(
              '${dog.ageText} · ${dog.breed} · ${sexes[dog.sex]} · dono(a) ${dog.ownerFirstName}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Chip(
                  avatar: const Icon(Icons.mood, size: 18),
                  label: Text(temperaments[dog.temperament] ?? dog.temperament),
                ),
                Chip(
                  backgroundColor: dog.bites ? scheme.errorContainer : null,
                  avatar: Icon(dog.bites ? Icons.warning : Icons.check_circle, size: 18),
                  label: Text(dog.bites ? 'Pode morder' : 'Não morde'),
                ),
                if (dog.inHeat) const Chip(avatar: Icon(Icons.info, size: 18), label: Text('No cio')),
                Chip(
                  backgroundColor: scheme.primaryContainer,
                  avatar: const Icon(Icons.vaccines, size: 18),
                  label: const Text('Vacinas em dia'),
                ),
                Chip(avatar: const Icon(Icons.bolt, size: 18), label: Text(activityLevels[dog.activityLevel] ?? '')),
                Chip(
                  avatar: Icon(dog.lookingFor == 'amizade' ? Icons.diversity_1 : Icons.favorite, size: 18),
                  label: Text(lookingForLabels[dog.lookingFor] ?? ''),
                ),
                if (dog.pedigreeVerified)
                  const Chip(
                    backgroundColor: likeYellow,
                    avatar: Icon(Icons.verified, size: 18, color: Color(0xFF231B00)),
                    label: Text('Pedigree', style: TextStyle(color: Color(0xFF231B00))),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dog.likes.isNotEmpty)
                  Expanded(
                    child: _LikeBox(title: 'AMA', text: dog.likes, love: true),
                  ),
                if (dog.likes.isNotEmpty && dog.dislikes.isNotEmpty) const SizedBox(width: 8),
                if (dog.dislikes.isNotEmpty)
                  Expanded(
                    child: _LikeBox(title: 'ODEIA', text: dog.dislikes, love: false),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LikeBox extends StatelessWidget {
  const _LikeBox({required this.title, required this.text, required this.love});
  final String title;
  final String text;
  final bool love;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: love ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(love ? 6 : 20),
          bottomRight: Radius.circular(love ? 20 : 6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          Text(text),
        ],
      ),
    );
  }
}

/// Comemoração do match: confete nas cores que o cachorro enxerga.
class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key, required this.mine, required this.other});
  final Dog mine;
  final Dog other;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    // "Au au!" ao dar match
    _player.play(AssetSource('sounds/au_au.wav')).catchError((_) {});
  }

  @override
  void dispose() {
    _player.dispose();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(colors: [Color(0xFF5C4FD6), Color(0xFF0B1A7A)], radius: 1.1),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _anim,
                builder: (_, _) => CustomPaint(
                  painter: _ConfettiPainter(_anim.value, [
                    scheme.primary,
                    likeYellow,
                    scheme.tertiary,
                    scheme.primaryContainer,
                  ]),
                ),
              ),
            ),
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutBack,
                builder: (context, v, child) => Transform.scale(scale: v, child: child),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Deu match!',
                      style: display(Theme.of(context).textTheme.displayLarge)?.copyWith(color: likeYellow),
                    ),
                    Text(
                      'AU AU! 🐶',
                      style: display(Theme.of(context).textTheme.headlineMedium)?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShapedDog(photoUrl: widget.mine.photoUrl, shape: Shapes.cookie9, size: 130),
                        const Icon(Icons.favorite, color: likeYellow, size: 48),
                        ShapedDog(photoUrl: widget.other.photoUrl, shape: Shapes.flower, size: 130),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '${widget.mine.name} e ${widget.other.name} querem se conhecer.',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: likeYellow,
                        foregroundColor: const Color(0xFF231B00),
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.pets),
                      label: const Text('Oba! Ver contato em Encontros'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.colors);
  final double t;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 40; i++) {
      final x = ((i * 37) % 100) / 100 * size.width;
      final y = ((t + (i % 9) / 9) % 1) * (size.height + 40) - 20;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((t * 6 + i) % 6.28);
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -8, 10, 16), const Radius.circular(3)),
        Paint()..color = colors[i % colors.length],
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
