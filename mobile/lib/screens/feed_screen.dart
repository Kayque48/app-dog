import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../api.dart';
import '../main.dart' show display, likeYellow;
import '../models.dart';
import '../widgets.dart';
import 'dog_detail_screen.dart';
import 'event_detail_screen.dart';
import 'events_screen.dart' show DateBadge;

/// Feed "cheio de vida": stories, post de destaque, blocos misturados
/// (cães perto, parque do dia, pedidos), curtida animada e aviso de fotos novas.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, this.onOpenTab});

  /// Abre outra aba da tela principal (1 = Descobrir, 2 = Encontros, 3 = Explorar).
  final ValueChanged<int>? onOpenTab;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final List<Map<String, dynamic>> _posts = [];
  final _scroll = ScrollController();
  int _page = 0;
  bool _loading = false;
  bool _end = false;
  String _myName = '';
  List<Dog> _myDogs = [];
  List<Dog> _nearby = [];
  Map<String, dynamic>? _park;
  List<Map<String, dynamic>> _events = [];
  int _requests = 0;
  int _fresh = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _loadExtras();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) _load();
    });
    // conteúdo constante: verifica fotos novas a cada 20 s
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _checkFresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (_end && !reset)) return;
    _loading = true;
    if (reset) {
      _page = 0;
      _end = false;
    }
    try {
      final data = List<Map<String, dynamic>>.from(await Api.instance.get('/feed?page=$_page'));
      if (!mounted) return;
      setState(() {
        if (reset) {
          _posts.clear();
          _fresh = 0;
        }
        _posts.addAll(data);
        _page++;
        _end = data.length < 20;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      _loading = false;
    }
  }

  /// Blocos extras do feed. Se algum falhar (sem localização, por exemplo), ele só não aparece.
  Future<void> _loadExtras() async {
    try {
      final me = await Api.instance.get('/me');
      final dogs = (await Api.instance.get('/dogs/mine') as List).map((j) => Dog.fromJson(j)).where((d) => !d.removed);
      _myName = (me['name'] as String).split(' ').first;
      _myDogs = dogs.toList();
      final matches = await Api.instance.get('/matches') as List;
      _requests = matches.where((m) => m['status'] == 'pending' && m['direction'] == 'incoming').length;
      if (mounted) setState(() {});
      if (_myDogs.isNotEmpty) {
        final near = await Api.instance.get('/discover?dog_id=${_myDogs.first.id}&radius_m=1000') as List;
        _nearby = near.map((j) => Dog.fromJson(j)).take(8).toList();
      }
      _events = List<Map<String, dynamic>>.from(await Api.instance.get('/events')).take(4).toList();
      if (mounted) setState(() {});
      final places = await Api.instance.get('/places?limit=1') as List;
      _park = places.isEmpty ? null : places.first;
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _checkFresh() async {
    try {
      final latest = List<Map<String, dynamic>>.from(await Api.instance.get('/feed?page=0'));
      final known = _posts.map((p) => p['id']).toSet();
      if (mounted) setState(() => _fresh = latest.where((p) => !known.contains(p['id'])).length);
    } catch (_) {}
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    try {
      final r = await Api.instance.post('/posts/${post['id']}/like');
      setState(() {
        post['liked_by_me'] = r['liked'];
        post['likes'] = r['likes'];
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _newPost() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const NewPostScreen()));
    if (created == true) _load(reset: true);
  }

  void _openDog(int id) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DogDetailScreen(dogId: id)));

  /// Monta a lista do feed misturando posts e blocos.
  List<Widget> _items() {
    final items = <Widget>[];
    for (var i = 0; i < _posts.length; i++) {
      final p = _posts[i];
      items.add(_PostCard(post: p, hero: i == 0, index: i, onLike: () => _toggleLike(p), onOpenDog: _openDog));
      if (i == 0 && _nearby.isNotEmpty) {
        items.add(_NearbyModule(dogs: _nearby, onOpen: () => widget.onOpenTab?.call(1)));
      }
      if (i == 2 && _park != null) {
        items.add(
          _ParkModule(park: _park!, dogName: _myDogs.firstOrNull?.name, onOpen: () => widget.onOpenTab?.call(3)),
        );
      }
      if (i == 3 && _events.isNotEmpty) {
        items.add(_EventsModule(events: _events, onOpenAll: () => widget.onOpenTab?.call(3)));
      }
      if (i == 4) items.add(const AdBanner());
      if (i == 5 && _requests > 0) {
        items.add(_RequestsModule(count: _requests, onOpen: () => widget.onOpenTab?.call(2)));
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stories = {for (final p in _posts) p['dog_id']: p}.values.take(12).toList();
    return Scaffold(
      floatingActionButton: FloatingActionButton.large(
        onPressed: _newPost,
        child: const Icon(Icons.add_a_photo, size: 36),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => _load(reset: true),
            child: Constrained(
              maxWidth: 720,
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.only(bottom: 120),
                children: [
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                      child: Text(
                        _myName.isEmpty ? 'All Love' : 'Oi, $_myName! 👋',
                        style: display(Theme.of(context).textTheme.displaySmall),
                      ),
                    ),
                  ),
                  // stories
                  SizedBox(
                    height: 116,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        if (_myDogs.isNotEmpty)
                          _Story(
                            photoUrl: _myDogs.first.photoUrl,
                            label: 'Seu post',
                            shape: Shapes.cookie9,
                            mine: true,
                            onTap: _newPost,
                          ),
                        for (var i = 0; i < stories.length; i++)
                          _Story(
                            photoUrl: stories[i]['dog_photo_url'],
                            label: stories[i]['dog_name'],
                            shape: Shapes.all[i % 4],
                            onTap: () => _openDog(stories[i]['dog_id']),
                          ),
                      ],
                    ),
                  ),
                  if (_posts.isEmpty && _end)
                    const EmptyState(icon: Icons.photo_camera, text: 'Ainda não há fotos. Seja o primeiro a publicar!'),
                  ..._items(),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _end ? 'Você viu tudo por hoje! 🐶' : 'Carregando mais fotos...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_fresh > 0)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilledButton.icon(
                    onPressed: () {
                      _load(reset: true);
                      _scroll.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
                    },
                    icon: const Icon(Icons.arrow_upward),
                    label: Text('$_fresh ${_fresh == 1 ? 'foto nova' : 'fotos novas'}'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Story extends StatelessWidget {
  const _Story({
    required this.photoUrl,
    required this.label,
    required this.shape,
    required this.onTap,
    this.mine = false,
  });
  final String? photoUrl;
  final String label;
  final ShapeBorder shape;
  final VoidCallback onTap;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            Stack(
              children: [
                // anel em degradê azul → violeta → amarelo, recortado na mesma forma
                Shaped(
                  shape: shape,
                  size: 84,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: mine
                          ? null
                          : SweepGradient(colors: [scheme.primary, scheme.tertiary, likeYellow, scheme.primary]),
                      color: mine ? scheme.outlineVariant : null,
                    ),
                    child: Center(
                      child: Shaped(
                        shape: shape,
                        size: 76,
                        child: ColoredBox(
                          color: scheme.surface,
                          child: Center(
                            child: ShapedDog(photoUrl: photoUrl, shape: shape, size: 70),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (mine)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: scheme.primary,
                      child: Icon(Icons.add, size: 18, color: scheme.onPrimary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 84,
              child: Text(
                label,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Post com cantos variados, curtida que "pula" e coração gigante no toque duplo.
class _PostCard extends StatefulWidget {
  const _PostCard({
    required this.post,
    required this.hero,
    required this.index,
    required this.onLike,
    required this.onOpenDog,
  });
  final Map<String, dynamic> post;
  final bool hero;
  final int index;
  final VoidCallback onLike;
  final ValueChanged<int> onOpenDog;

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> with TickerProviderStateMixin {
  late final _heart = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  // cada post ganha um formato de cantos diferente
  static const _radii = [
    BorderRadius.all(Radius.circular(40)),
    BorderRadius.only(
      topLeft: Radius.circular(80),
      topRight: Radius.circular(24),
      bottomLeft: Radius.circular(24),
      bottomRight: Radius.circular(80),
    ),
    BorderRadius.only(
      topLeft: Radius.circular(24),
      topRight: Radius.circular(80),
      bottomLeft: Radius.circular(80),
      bottomRight: Radius.circular(24),
    ),
    BorderRadius.only(
      topLeft: Radius.circular(200),
      topRight: Radius.circular(200),
      bottomLeft: Radius.circular(28),
      bottomRight: Radius.circular(28),
    ),
  ];

  @override
  void dispose() {
    _heart.dispose();
    _pop.dispose();
    super.dispose();
  }

  void _like() {
    _pop.forward(from: 0);
    widget.onLike();
  }

  void _doubleTap() {
    _heart.forward(from: 0);
    if (widget.post['liked_by_me'] != true) _like();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = widget.post;
    final liked = p['liked_by_me'] == true;
    final radius = widget.hero
        ? const BorderRadius.only(
            topLeft: Radius.circular(56),
            topRight: Radius.circular(56),
            bottomRight: Radius.circular(56),
            bottomLeft: Radius.circular(12),
          )
        : _radii[widget.index % 4];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onDoubleTap: _doubleTap,
            child: ClipRRect(
              borderRadius: radius,
              child: AspectRatio(
                aspectRatio: widget.hero ? 1 : (widget.index.isOdd ? 4 / 5 : 1),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (p['media_type'] == 'video')
                      FeedVideo(url: Api.imageUrl(p['image_url'])!)
                    else
                      DogPhoto(photoUrl: p['image_url'], height: double.infinity),
                    if (widget.hero)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, const Color(0xFF000A3C).withValues(alpha: 0.75)],
                          ),
                        ),
                      ),
                    if (widget.hero)
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Chip(
                              backgroundColor: scheme.secondaryContainer,
                              avatar: Icon(Icons.local_fire_department, color: scheme.onSecondaryContainer),
                              label: const Text('Em alta'),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              (p['caption'] as String).isEmpty ? p['dog_name'] : p['caption'],
                              style: display(Theme.of(context).textTheme.headlineLarge)?.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    // coração gigante do toque duplo
                    Center(
                      child: AnimatedBuilder(
                        animation: _heart,
                        builder: (_, _) {
                          final t = _heart.value;
                          if (t == 0 || t == 1) return const SizedBox.shrink();
                          final scale = t < 0.25
                              ? Curves.easeOutBack.transform(t / 0.25) * 1.15
                              : 1.0 + (t > 0.6 ? (t - 0.6) : 0);
                          return Opacity(
                            opacity: t < 0.6 ? 1 : (1 - (t - 0.6) / 0.4),
                            child: Transform.scale(
                              scale: scale,
                              child: const Icon(Icons.favorite, size: 140, color: likeYellow),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => widget.onOpenDog(p['dog_id']),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        ShapedDog(photoUrl: p['dog_photo_url'], shape: Shapes.cookie12, size: 40),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p['dog_name'], style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text(p['dog_breed'], style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: scheme.surfaceContainerHigh,
                ),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => CommentsSheet(postId: p['id'], onCount: (n) => setState(() => p['comments'] = n)),
                ),
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text('${p['comments'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 6),
              // botão de curtir em pílula, que "pula" ao tocar
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: liked ? scheme.secondaryContainer : scheme.surfaceContainerHigh,
                  foregroundColor: liked ? scheme.onSecondaryContainer : scheme.onSurface,
                ),
                onPressed: _like,
                icon: ScaleTransition(
                  scale: TweenSequence([
                    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 40),
                    TweenSequenceItem(tween: Tween(begin: 1.5, end: 0.9), weight: 30),
                    TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 30),
                  ]).animate(_pop),
                  child: Icon(liked ? Icons.favorite : Icons.favorite_border),
                ),
                label: Text('${p['likes']}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          if (!widget.hero && (p['caption'] as String).isNotEmpty)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(p['caption'])),
        ],
      ),
    );
  }
}

/// Vídeo do feed: toca sozinho, sem som e em loop (toque para ligar o som).
class FeedVideo extends StatefulWidget {
  const FeedVideo({super.key, required this.url});
  final String url;

  @override
  State<FeedVideo> createState() => _FeedVideoState();
}

class _FeedVideoState extends State<FeedVideo> {
  late final _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _controller
        .initialize()
        .then((_) {
          _controller
            ..setLooping(true)
            ..setVolume(0)
            ..play();
          if (mounted) setState(() {});
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!_controller.value.isInitialized) {
      return ColoredBox(
        color: scheme.primaryContainer,
        child: Icon(Icons.play_circle, size: 72, color: scheme.onPrimaryContainer),
      );
    }
    return GestureDetector(
      onTap: () => setState(() {
        _muted = !_muted;
        _controller.setVolume(_muted ? 0 : 1);
      }),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: Icon(_muted ? Icons.volume_off : Icons.volume_up, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Comentários de uma publicação (folha que sobe de baixo).
class CommentsSheet extends StatefulWidget {
  const CommentsSheet({super.key, required this.postId, required this.onCount});
  final int postId;
  final ValueChanged<int> onCount;

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  List<Map<String, dynamic>>? _items;
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = List<Map<String, dynamic>>.from(await Api.instance.get('/posts/${widget.postId}/comments'));
      if (!mounted) return;
      setState(() => _items = data);
      widget.onCount(data.length);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _send() async {
    if (_text.text.trim().isEmpty) return;
    try {
      await Api.instance.post('/posts/${widget.postId}/comments', {'text': _text.text});
      _text.clear();
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = _items;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: [
            Text('Comentários', style: Theme.of(context).textTheme.titleLarge),
            Expanded(
              child: items == null
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                  ? const EmptyState(icon: Icons.chat_bubble_outline, text: 'Seja o primeiro a comentar!')
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final c in items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ShapedDog(photoUrl: c['author_photo'], shape: Shapes.cookie12, size: 36),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: scheme.surfaceContainerHigh,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(18),
                                        topRight: Radius.circular(18),
                                        bottomRight: Radius.circular(18),
                                        bottomLeft: Radius.circular(4),
                                      ),
                                    ),
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '${c['author']} ',
                                            style: const TextStyle(fontWeight: FontWeight.w800),
                                          ),
                                          TextSpan(text: c['text']),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        maxLength: 500,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(hintText: 'Escreva um comentário...', counterText: ''),
                      ),
                    ),
                    IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
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

class _NearbyModule extends StatelessWidget {
  const _NearbyModule({required this.dogs, required this.onOpen});
  final List<Dog> dogs;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(40)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Perto de você agora', style: Theme.of(context).textTheme.headlineSmall)),
              TextButton(onPressed: onOpen, child: const Text('Ver todos')),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dogs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final d = dogs[i];
                return GestureDetector(
                  onTap: onOpen,
                  child: Column(
                    children: [
                      ShapedDog(photoUrl: d.photoUrl, shape: Shapes.all[(i + 1) % 4], size: 104),
                      const SizedBox(height: 6),
                      Text(d.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(formatDistance(d.distanceM ?? 0), style: Theme.of(context).textTheme.bodySmall),
                      if (d.wantsToMeetYou)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'quer te conhecer!',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ParkModule extends StatelessWidget {
  const _ParkModule({required this.park, required this.dogName, required this.onOpen});
  final Map<String, dynamic> park;
  final String? dogName;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(80),
          topRight: Radius.circular(28),
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(80),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Shaped(
                shape: Shapes.flower,
                size: 72,
                child: ColoredBox(
                  color: scheme.primary,
                  child: Icon(Icons.park, size: 36, color: scheme.onPrimary),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'PARQUE DO DIA',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5, color: scheme.onSecondaryContainer),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            park['name'],
            style: display(Theme.of(context).textTheme.headlineMedium)?.copyWith(color: scheme.onSecondaryContainer),
          ),
          const SizedBox(height: 4),
          Text(
            'a ${formatDistance(park['distance_m'])} de você. Bora levar ${dogName ?? 'seu cão'}?',
            style: TextStyle(color: scheme.onSecondaryContainer),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.onSecondaryContainer,
              foregroundColor: scheme.secondaryContainer,
            ),
            onPressed: onOpen,
            child: const Text('Ver parques'),
          ),
        ],
      ),
    );
  }
}

class _EventsModule extends StatelessWidget {
  const _EventsModule({required this.events, required this.onOpenAll});
  final List<Map<String, dynamic>> events;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 20),
      decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(40)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Rolês que vêm aí 🎉',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: scheme.onTertiaryContainer),
                ),
              ),
              TextButton(onPressed: onOpenAll, child: const Text('Ver todos')),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final e = events[i];
                final d = EventDate(e['starts_at']);
                return GestureDetector(
                  onTap: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: e['id']))),
                  child: SizedBox(
                    width: 200,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(32),
                            topRight: Radius.circular(32),
                            bottomRight: Radius.circular(32),
                            bottomLeft: Radius.circular(8),
                          ),
                          child: SizedBox(
                            height: 130,
                            width: 200,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ColoredBox(
                                  color: scheme.primaryContainer,
                                  child: Icon(eventKinds[e['kind']]!.$2, size: 48, color: scheme.onPrimaryContainer),
                                ),
                                if (e['cover_url'] != null)
                                  Image.network(
                                    Api.imageUrl(e['cover_url'])!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const SizedBox(),
                                  ),
                                Positioned(left: 8, top: 8, child: DateBadge(date: d, size: 56)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          e['title'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: display(const TextStyle(fontSize: 16))?.copyWith(color: scheme.onTertiaryContainer),
                        ),
                        Text(
                          '${d.countdown} · ${e['going']} vão${e['has_contest'] == true ? ' · 🏆' : ''}',
                          style: TextStyle(fontSize: 12, color: scheme.onTertiaryContainer),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestsModule extends StatelessWidget {
  const _RequestsModule({required this.count, required this.onOpen});
  final int count;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(40)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count ${count == 1 ? 'cão quer' : 'cães querem'} te conhecer 💙',
            style: display(Theme.of(context).textTheme.headlineMedium)?.copyWith(color: scheme.onTertiaryContainer),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onOpen, child: const Text('Responder agora')),
        ],
      ),
    );
  }
}

/// Publicar uma foto de um dos meus cães.
class NewPostScreen extends StatefulWidget {
  const NewPostScreen({super.key});

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  List<Dog> _dogs = [];
  int? _dogId;
  XFile? _image;
  bool _isVideo = false;
  final _caption = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    Api.instance
        .get('/dogs/mine')
        .then((data) {
          final dogs = (data as List).map((j) => Dog.fromJson(j)).where((d) => !d.removed).toList();
          if (!mounted) return;
          setState(() {
            _dogs = dogs;
            _dogId = dogs.isEmpty ? null : dogs.first.id;
          });
        })
        .catchError((e) {
          if (mounted) showError(context, e);
        });
  }

  Future<void> _pick(ImageSource source) async {
    final img = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (img == null) return;
    setState(() {
      _image = img;
      _isVideo = false;
    });
  }

  Future<void> _pickVideo() async {
    final video = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 60));
    if (video == null) return;
    setState(() {
      _image = video;
      _isVideo = true;
    });
  }

  Future<void> _send() async {
    if (_image == null || _dogId == null) return;
    setState(() => _sending = true);
    try {
      final url = await Api.instance.upload(_image!.path);
      await Api.instance.post('/posts', {'dog_id': _dogId, 'image_url': url, 'caption': _caption.text});
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova publicação')),
      body: Constrained(
        child: _dogs.isEmpty
            ? const EmptyState(icon: Icons.pets, text: 'Cadastre um cão na aba Perfil antes de publicar.')
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _dogId,
                    decoration: const InputDecoration(labelText: 'Cão'),
                    items: [for (final d in _dogs) DropdownMenuItem(value: d.id, child: Text(d.name))],
                    onChanged: (v) => setState(() => _dogId = v),
                  ),
                  const SizedBox(height: 12),
                  if (_image != null && !_isVideo) Image.file(File(_image!.path), height: 240, fit: BoxFit.cover),
                  if (_image != null && _isVideo)
                    ListTile(leading: const Icon(Icons.movie, size: 36), title: Text('Vídeo: ${_image!.name}')),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pick(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera),
                          label: const Text('Câmera'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pick(ImageSource.gallery),
                          icon: const Icon(Icons.photo),
                          label: const Text('Galeria'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickVideo,
                          icon: const Icon(Icons.videocam),
                          label: const Text('Vídeo'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _caption,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Legenda'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _sending || _image == null ? null : _send,
                    child: Text(_sending ? 'Publicando...' : 'Publicar'),
                  ),
                ],
              ),
      ),
    );
  }
}
