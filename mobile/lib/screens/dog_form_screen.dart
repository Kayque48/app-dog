import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../models.dart';
import '../widgets.dart';

/// Cadastro ou edição do cão (formulário simples, de propósito).
class DogFormScreen extends StatefulWidget {
  const DogFormScreen({super.key, this.dog});
  final Dog? dog;

  @override
  State<DogFormScreen> createState() => _DogFormScreenState();
}

class _DogFormScreenState extends State<DogFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.dog?.name);
  late final _breed = TextEditingController(text: widget.dog?.breed);
  late final _likes = TextEditingController(text: widget.dog?.likes);
  late final _dislikes = TextEditingController(text: widget.dog?.dislikes);
  late DateTime? _birth = widget.dog == null ? null : DateTime.parse(widget.dog!.birthDate);
  late String _sex = widget.dog?.sex ?? 'macho';
  late String _temperament = widget.dog?.temperament ?? 'calmo';
  late bool _bites = widget.dog?.bites ?? false;
  late bool _inHeat = widget.dog?.inHeat ?? false;
  late String? _photoUrl = widget.dog?.photoUrl;
  late final _weight = TextEditingController(text: widget.dog?.weightKg?.toString() ?? '');
  late final _color = TextEditingController(text: widget.dog?.color);
  late final _bio = TextEditingController(text: widget.dog?.bio);
  late final _microchip = TextEditingController(text: widget.dog?.microchip);
  late final _allergies = TextEditingController(text: widget.dog?.allergies);
  late final _health = TextEditingController(text: widget.dog?.healthNotes);
  late String _activity = widget.dog?.activityLevel ?? 'medio';
  late String _lookingFor = widget.dog?.lookingFor ?? 'amizade';
  late bool _neutered = widget.dog?.neutered ?? false;
  bool _saving = false;

  Future<void> _pickPhoto() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (img == null) return;
    try {
      final url = await Api.instance.upload(img.path);
      setState(() => _photoUrl = url);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _pickBirth() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime.now().subtract(const Duration(days: 365)),
      firstDate: DateTime(1995),
      lastDate: DateTime.now(),
      helpText: 'Data de nascimento (aproximada)',
    );
    if (d != null) setState(() => _birth = d);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_birth == null) {
      showMessage(context, 'Informe a data de nascimento');
      return;
    }
    setState(() => _saving = true);
    final body = {
      'name': _name.text,
      'breed': _breed.text,
      'birth_date': isoDate(_birth!),
      'sex': _sex,
      'in_heat': _sex == 'femea' && _inHeat,
      'temperament': _temperament,
      'bites': _bites,
      'likes': _likes.text,
      'dislikes': _dislikes.text,
      'photo_url': _photoUrl,
      'weight_kg': double.tryParse(_weight.text.replaceAll(',', '.')),
      'color': _color.text,
      'bio': _bio.text,
      'activity_level': _activity,
      'looking_for': _neutered ? 'amizade' : _lookingFor,
      'microchip': _microchip.text,
      'neutered': _neutered,
      'allergies': _allergies.text,
      'health_notes': _health.text,
    };
    try {
      if (widget.dog == null) {
        await Api.instance.post('/dogs', body);
      } else {
        await Api.instance.put('/dogs/${widget.dog!.id}', body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String? req(String? v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null;
    return Scaffold(
      appBar: AppBar(title: Text(widget.dog == null ? 'Cadastrar cão' : 'Editar ${widget.dog!.name}')),
      body: Constrained(
        maxWidth: 520,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      DogAvatar(photoUrl: _photoUrl, radius: 56),
                      const CircleAvatar(radius: 16, child: Icon(Icons.camera_alt, size: 18)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                validator: req,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _breed,
                validator: req,
                decoration: const InputDecoration(labelText: 'Raça (ou vira-lata)'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickBirth,
                icon: const Icon(Icons.cake),
                label: Text(_birth == null ? 'Data de nascimento' : 'Nascimento: ${formatDate(isoDate(_birth!))}'),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [for (final e in sexes.entries) ButtonSegment(value: e.key, label: Text(e.value))],
                selected: {_sex},
                onSelectionChanged: (s) => setState(() => _sex = s.first),
              ),
              if (_sex == 'femea')
                SwitchListTile(
                  title: const Text('Está no cio'),
                  value: _inHeat,
                  onChanged: (v) => setState(() => _inHeat = v),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _temperament,
                decoration: const InputDecoration(labelText: 'Temperamento'),
                items: [for (final e in temperaments.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setState(() => _temperament = v!),
              ),
              SwitchListTile(
                title: const Text('Costuma morder'),
                value: _bites,
                onChanged: (v) => setState(() => _bites = v),
              ),
              TextFormField(
                controller: _likes,
                decoration: const InputDecoration(labelText: 'Do que gosta (ex.: morder bolinha)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dislikes,
                decoration: const InputDecoration(labelText: 'Do que não gosta (ex.: chinelo)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weight,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Peso (kg)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _color,
                      decoration: const InputDecoration(labelText: 'Cor'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bio,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Descrição (temperamento, manias...)'),
              ),
              const SizedBox(height: 16),
              const Text('Nível de atividade'),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: [for (final e in activityLevels.entries) ButtonSegment(value: e.key, label: Text(e.value))],
                selected: {_activity},
                onSelectionChanged: (s) => setState(() => _activity = s.first),
              ),
              const SizedBox(height: 16),
              const Text('Procura'),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: [
                  for (final e in lookingForLabels.entries)
                    ButtonSegment(
                      value: e.key,
                      label: Text(e.key == 'ambos' ? 'Os dois' : e.value),
                      enabled: !_neutered || e.key == 'amizade',
                    ),
                ],
                selected: {_neutered ? 'amizade' : _lookingFor},
                onSelectionChanged: (s) => setState(() => _lookingFor = s.first),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.badge, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Carteira digital', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              SwitchListTile(
                title: const Text('Castrado'),
                value: _neutered,
                onChanged: (v) => setState(() => _neutered = v),
              ),
              TextFormField(
                controller: _microchip,
                decoration: const InputDecoration(labelText: 'Microchip'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _allergies,
                decoration: const InputDecoration(labelText: 'Alergias'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _health,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Observações de saúde'),
              ),
              const SizedBox(height: 20),
              if (widget.dog == null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Depois de salvar, registre as vacinas no perfil do cão. '
                    'Sem V8/V10 e antirrábica em dia ele não aparece no Descobrir.',
                  ),
                ),
              FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Salvando...' : 'Salvar')),
            ],
          ),
        ),
      ),
    );
  }
}
