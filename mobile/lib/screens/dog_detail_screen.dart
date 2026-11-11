import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../widgets.dart';
import 'dog_form_screen.dart';
import 'owner_screen.dart';

/// Perfil do cão: dados, carteira de vacinação, histórico e denúncia.
class DogDetailScreen extends StatefulWidget {
  const DogDetailScreen({super.key, required this.dogId});
  final int dogId;

  @override
  State<DogDetailScreen> createState() => _DogDetailScreenState();
}

class _DogDetailScreenState extends State<DogDetailScreen> {
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _vaccines = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.instance.get('/dogs/${widget.dogId}');
      final vaccines = List<Map<String, dynamic>>.from(await Api.instance.get('/dogs/${widget.dogId}/vaccines'));
      if (!mounted) return;
      setState(() {
        _data = data;
        _vaccines = vaccines;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  bool get _isMine => _data?['is_mine'] == true;

  Future<void> _addVaccine() async {
    String name = vaccineNames.first;
    DateTime applied = DateTime.now();
    DateTime? nextDue = DateTime.now().add(const Duration(days: 365));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> pick(bool isNext) async {
            final d = await showDatePicker(
              context: ctx,
              initialDate: isNext ? (nextDue ?? DateTime.now()) : applied,
              firstDate: DateTime(2000),
              lastDate: isNext ? DateTime(2100) : DateTime.now(),
            );
            if (d != null) setLocal(() => isNext ? nextDue = d : applied = d);
          }

          return AlertDialog(
            title: const Text('Registrar vacina'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: name,
                  decoration: const InputDecoration(labelText: 'Vacina'),
                  items: [for (final v in vaccineNames) DropdownMenuItem(value: v, child: Text(v))],
                  onChanged: (v) => setLocal(() => name = v!),
                ),
                ListTile(
                  title: const Text('Aplicada em'),
                  subtitle: Text(formatDate(isoDate(applied))),
                  onTap: () => pick(false),
                ),
                ListTile(
                  title: const Text('Próximo reforço'),
                  subtitle: Text(nextDue == null ? 'Sem reforço' : formatDate(isoDate(nextDue!))),
                  onTap: () => pick(true),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    try {
      await Api.instance.post('/dogs/${widget.dogId}/vaccines', {
        'name': name,
        'applied_on': isoDate(applied),
        'next_due': nextDue == null ? null : isoDate(nextDue!),
      });
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _report() async {
    String reason = reportReasons.keys.first;
    final details = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Denunciar'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioGroup<String>(
                  groupValue: reason,
                  onChanged: (v) => setLocal(() => reason = v!),
                  child: Column(
                    children: [
                      for (final e in reportReasons.entries)
                        RadioListTile<String>(value: e.key, title: Text(e.value), dense: true),
                    ],
                  ),
                ),
                TextField(
                  controller: details,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'O que aconteceu?'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enviar denúncia')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final r = await Api.instance.post('/reports', {
        'target_dog_id': widget.dogId,
        'reason': reason,
        'details': details.text,
      });
      if (mounted) showMessage(context, r['message']);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _edit(Dog dog) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => DogFormScreen(dog: dog)));
    if (changed == true) _load();
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
    final dog = Dog.fromJson(data['dog']);
    final history = List<Map<String, dynamic>>.from(data['history']);
    final t = Theme.of(context).textTheme;
    final status = dog.vaccineStatus;

    return Scaffold(
      appBar: AppBar(
        title: Text(dog.name),
        actions: [
          if (_isMine && !dog.removed) IconButton(icon: const Icon(Icons.edit), onPressed: () => _edit(dog)),
          if (!_isMine) IconButton(icon: const Icon(Icons.flag), tooltip: 'Denunciar', onPressed: _report),
        ],
      ),
      body: Constrained(
        child: ListView(
          children: [
            DogPhoto(photoUrl: dog.photoUrl),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${dog.name}, ${dog.ageText}', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  Text('${dog.breed} • ${sexes[dog.sex]}${dog.inHeat ? ' • no cio' : ''}'),
                  TextButton.icon(
                    icon: const Icon(Icons.person),
                    label: Text('Dono(a): ${data['owner']['first_name']}'),
                    onPressed: () =>
                        Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => OwnerScreen(userId: data['owner']['id']))),
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      Chip(label: Text(temperaments[dog.temperament] ?? dog.temperament)),
                      Chip(label: Text(dog.bites ? 'Pode morder' : 'Não morde')),
                    ],
                  ),
                  if (dog.likes.isNotEmpty) Text('Gosta de: ${dog.likes}'),
                  if (dog.dislikes.isNotEmpty) Text('Não gosta de: ${dog.dislikes}'),
                  const Divider(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Carteira de vacinação',
                          style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_isMine && !dog.removed)
                        TextButton.icon(
                          onPressed: _addVaccine,
                          icon: const Icon(Icons.add),
                          label: const Text('Vacina'),
                        ),
                    ],
                  ),
                  Card.filled(
                    color: status.upToDate ? successContainer(context) : Theme.of(context).colorScheme.errorContainer,
                    child: ListTile(
                      leading: Icon(
                        status.upToDate ? Icons.verified : Icons.block,
                        color: status.upToDate ? successColor(context) : Theme.of(context).colorScheme.error,
                      ),
                      title: Text(status.description),
                      subtitle: status.upToDate
                          ? null
                          : const Text('Com vacina atrasada ou faltando, o cão fica bloqueado no Descobrir.'),
                    ),
                  ),
                  for (final v in _vaccines)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.vaccines),
                      title: Text(v['name']),
                      subtitle: Text(
                        'Aplicada em ${formatDate(v['applied_on'])}'
                        '${v['next_due'] != null ? ' • reforço em ${formatDate(v['next_due'])}' : ''}',
                      ),
                    ),
                  const Divider(height: 32),
                  Text('Histórico', style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  for (final h in history)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        h['kind'] == 'incidente' ? Icons.warning : Icons.history,
                        color: h['kind'] == 'incidente' ? Theme.of(context).colorScheme.error : null,
                      ),
                      title: Text(h['description']),
                      subtitle: Text(formatDate(h['created_at'])),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
