import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../models.dart';
import '../widgets.dart';
import 'dog_detail_screen.dart';

/// Feed de fotos: o dono rola, curte e publica fotos do seu cão.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final List<Map<String, dynamic>> _posts = [];
  final _scroll = ScrollController();
  int _page = 0;
  bool _loading = false;
  bool _end = false;

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _load();
    });
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
        if (reset) _posts.clear();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Love')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newPost,
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Publicar'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: _posts.isEmpty && _end
            ? ListView(children: const [
                SizedBox(height: 120),
                EmptyState(icon: Icons.photo_camera, text: 'Ainda não há fotos. Seja o primeiro a publicar!'),
              ])
            : Constrained(
                child: ListView.builder(
                  controller: _scroll,
                  itemCount: _posts.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) return const AdBanner();
                    return _PostCard(post: _posts[i - 1], onLike: () => _toggleLike(_posts[i - 1]));
                  },
                ),
              ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.onLike});
  final Map<String, dynamic> post;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final liked = post['liked_by_me'] == true;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ListTile(
          leading: DogAvatar(photoUrl: post['dog_photo_url']),
          title: Text(post['dog_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(post['dog_breed']),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => DogDetailScreen(dogId: post['dog_id']))),
        ),
        GestureDetector(onDoubleTap: liked ? null : onLike, child: DogPhoto(photoUrl: post['image_url'], height: 320)),
        Row(children: [
          IconButton(
            iconSize: 30,
            icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? Colors.red : null),
            onPressed: onLike,
          ),
          Text('${post['likes']} curtida(s)'),
        ]),
        if ((post['caption'] as String).isNotEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Text(post['caption'])),
      ]),
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
  final _caption = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    Api.instance.get('/dogs/mine').then((data) {
      final dogs = (data as List).map((j) => Dog.fromJson(j)).where((d) => !d.removed).toList();
      if (!mounted) return;
      setState(() {
        _dogs = dogs;
        _dogId = dogs.isEmpty ? null : dogs.first.id;
      });
    }).catchError((e) {
      if (mounted) showError(context, e);
    });
  }

  Future<void> _pick(ImageSource source) async {
    final img = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (img != null) setState(() => _image = img);
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
            : ListView(padding: const EdgeInsets.all(16), children: [
                DropdownButtonFormField<int>(
                  initialValue: _dogId,
                  decoration: const InputDecoration(labelText: 'Cão'),
                  items: [for (final d in _dogs) DropdownMenuItem(value: d.id, child: Text(d.name))],
                  onChanged: (v) => setState(() => _dogId = v),
                ),
                const SizedBox(height: 12),
                if (_image != null) Image.file(File(_image!.path), height: 240, fit: BoxFit.cover),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                        onPressed: () => _pick(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('Câmera')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                        onPressed: () => _pick(ImageSource.gallery),
                        icon: const Icon(Icons.photo),
                        label: const Text('Galeria')),
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(controller: _caption, maxLines: 3, decoration: const InputDecoration(labelText: 'Legenda')),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _sending || _image == null ? null : _send,
                  child: Text(_sending ? 'Publicando...' : 'Publicar'),
                ),
              ]),
      ),
    );
  }
}
