import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../main.dart' show display, likeYellow;
import '../models.dart';
import '../widgets.dart';

/// Carteira digital do cão: identidade pet e documentos (pedigree, exames, RG animal...).
/// Os documentos só aparecem para o dono; o pedigree verificado vira selo no perfil.
class DogWallet extends StatefulWidget {
  const DogWallet({super.key, required this.dog, required this.isMine});
  final Dog dog;
  final bool isMine;

  @override
  State<DogWallet> createState() => _DogWalletState();
}

class _DogWalletState extends State<DogWallet> {
  List<Map<String, dynamic>> _docs = [];

  @override
  void initState() {
    super.initState();
    if (widget.isMine) _load();
  }

  Future<void> _load() async {
    try {
      final data = List<Map<String, dynamic>>.from(await Api.instance.get('/dogs/${widget.dog.id}/documents'));
      if (mounted) setState(() => _docs = data);
    } catch (_) {}
  }

  Future<void> _add() async {
    String kind = 'pedigree';
    final title = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Novo documento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: kind,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [for (final e in docKinds.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setLocal(() => kind = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 8),
              const Text('Em seguida, escolha o arquivo (PDF ou foto).'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Escolher arquivo')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    final path = picked.isEmpty ? null : picked.single.path;
    if (path == null) return;
    try {
      final url = await Api.instance.upload(path);
      await Api.instance.post('/dogs/${widget.dog.id}/documents', {
        'kind': kind,
        'title': title.text.trim().isEmpty ? docKinds[kind] : title.text,
        'file_url': url,
      });
      if (mounted) {
        showMessage(
          context,
          kind == 'pedigree' ? 'Pedigree enviado! A moderação vai verificar.' : 'Documento guardado',
        );
      }
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _remove(Map<String, dynamic> doc) async {
    try {
      await Api.instance.delete('/documents/${doc['id']}');
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = widget.dog;
    const white = TextStyle(color: Colors.white);
    Widget field(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1)),
        Text(value, style: white),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.badge, color: scheme.primary, size: 30),
            const SizedBox(width: 8),
            Text('Carteira digital', style: display(Theme.of(context).textTheme.headlineSmall)),
          ],
        ),
        const SizedBox(height: 12),
        // "identidade pet" em degradê azul → violeta
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary]),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
              bottomRight: Radius.circular(32),
              bottomLeft: Radius.circular(8),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 0,
                child: Shaped(
                  shape: Shapes.cookie9,
                  size: 64,
                  child: const ColoredBox(
                    color: likeYellow,
                    child: Icon(Icons.pets, color: Color(0xFF231B00)),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'IDENTIDADE PET',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: 2),
                  ),
                  Text(
                    d.name,
                    style: display(Theme.of(context).textTheme.headlineLarge)?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 24,
                    runSpacing: 10,
                    children: [
                      field('Raça', d.breed),
                      field('Nascimento', formatDate(d.birthDate)),
                      field('Sexo', sexes[d.sex] ?? ''),
                      field('Castrado', d.neutered ? 'Sim' : 'Não'),
                      field('Peso', d.weightKg == null ? '—' : '${d.weightKg} kg'),
                      field('Cor', d.color.isEmpty ? '—' : d.color),
                      field('Microchip', d.microchip.isEmpty ? 'Não informado' : d.microchip),
                      if (widget.isMine) field('Alergias', d.allergies.isEmpty ? 'Nenhuma' : d.allergies),
                      if (widget.isMine && d.healthNotes.isNotEmpty) field('Saúde', d.healthNotes),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        if (widget.isMine) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text('Documentos', style: Theme.of(context).textTheme.titleMedium)),
              TextButton.icon(onPressed: _add, icon: const Icon(Icons.upload_file), label: const Text('Adicionar')),
            ],
          ),
          if (_docs.isEmpty) const Text('Nenhum documento ainda.'),
          for (final x in _docs)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(x['kind'] == 'pedigree' ? Icons.workspace_premium : Icons.description),
              title: Text(x['title']),
              subtitle: Text('${docKinds[x['kind']]} · ${formatDate(x['created_at'])}'),
              onTap: () => launchUrl(Uri.parse(Api.imageUrl(x['file_url'])!), mode: LaunchMode.externalApplication),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (x['kind'] == 'pedigree')
                    Chip(
                      backgroundColor: x['status'] == 'verificado'
                          ? scheme.primaryContainer
                          : (x['status'] == 'recusado' ? scheme.errorContainer : scheme.surfaceContainerHigh),
                      label: Text(
                        x['status'] == 'verificado'
                            ? 'Verificado'
                            : (x['status'] == 'recusado' ? 'Recusado' : 'Em análise'),
                      ),
                    ),
                  IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _remove(x)),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
