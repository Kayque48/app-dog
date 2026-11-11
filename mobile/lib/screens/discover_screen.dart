import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
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
      final data = await Api.instance.get('/discover?dog_id=${dog.id}&radius_m=$_radius');
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
    setState(() => _cards.remove(other));
    try {
      final r = await Api.instance.post('/swipes', {'from_dog_id': _myDog!.id, 'to_dog_id': other.id, 'liked': liked});
      if (!mounted) return;
      if (r['matched'] == true) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Encontro combinado! 🐾'),
            content: Text(
              '${_myDog!.name} e ${other.name} querem se conhecer. '
              'Veja o contato do dono na aba Encontros.',
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Oba!'))],
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
    return Scaffold(
      appBar: AppBar(title: const Text('Descobrir')),
      body: Constrained(
        maxWidth: 520,
        child: Column(
          children: [
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
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final r in [500, 1000, 3000])
                    ChoiceChip(
                      label: Text('Até ${formatDistance(r)}'),
                      selected: _radius == r,
                      onSelected: (_) {
                        _radius = r;
                        _loadCards();
                      },
                    ),
                ],
              ),
            ),
            Expanded(child: _body()),
          ],
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
        icon: Icons.vaccines,
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
        icon: Icons.search,
        text: 'Nenhum cão novo por perto agora. Tente aumentar a distância.',
        action: OutlinedButton(onPressed: _loadCards, child: const Text('Atualizar')),
      );
    }
    final dog = _cards.first;
    return Column(
      children: [
        Expanded(
          child: Dismissible(
            key: ValueKey(dog.id),
            onDismissed: (dir) => _swipe(dog, dir == DismissDirection.startToEnd),
            background: _swipeHint(Icons.favorite, successColor(context), Alignment.centerLeft),
            secondaryBackground: _swipeHint(Icons.close, Theme.of(context).colorScheme.error, Alignment.centerRight),
            child: _DogCard(dog: dog),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton.large(
                heroTag: 'pass',
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                onPressed: () => _swipe(dog, false),
                child: const Icon(Icons.close, size: 40),
              ),
              FloatingActionButton.large(
                heroTag: 'like',
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                onPressed: () => _swipe(dog, true),
                child: const Icon(Icons.favorite, size: 40),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _swipeHint(IconData icon, Color color, Alignment align) => Container(
    alignment: align,
    padding: const EdgeInsets.symmetric(horizontal: 32),
    child: Icon(icon, color: color, size: 64),
  );
}

class _DogCard extends StatelessWidget {
  const _DogCard({required this.dog});
  final Dog dog;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DogDetailScreen(dogId: dog.id))),
        child: ListView(
          children: [
            DogPhoto(photoUrl: dog.photoUrl, height: 280),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dog.wantsToMeetYou)
                    Chip(
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                      avatar: const Icon(Icons.favorite),
                      label: const Text('Quer conhecer o seu cão!'),
                    ),
                  Text('${dog.name}, ${dog.ageText}', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  Text('${dog.breed} • ${sexes[dog.sex]} • a ${formatDistance(dog.distanceM ?? 0)}'),
                  Text('Dono(a): ${dog.ownerFirstName}'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Chip(label: Text(temperaments[dog.temperament] ?? dog.temperament)),
                      Chip(
                        avatar: Icon(dog.bites ? Icons.warning : Icons.check, size: 18),
                        label: Text(dog.bites ? 'Pode morder' : 'Não morde'),
                      ),
                      if (dog.inHeat) const Chip(avatar: Icon(Icons.info, size: 18), label: Text('No cio')),
                      const Chip(avatar: Icon(Icons.vaccines, size: 18), label: Text('Vacinas em dia')),
                    ],
                  ),
                  if (dog.likes.isNotEmpty) ...[const SizedBox(height: 8), Text('Gosta de: ${dog.likes}')],
                  if (dog.dislikes.isNotEmpty) Text('Não gosta de: ${dog.dislikes}'),
                  const SizedBox(height: 8),
                  Text('Toque para ver o perfil completo', style: t.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
