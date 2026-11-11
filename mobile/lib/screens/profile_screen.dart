import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../widgets.dart';
import 'dog_detail_screen.dart';
import 'dog_form_screen.dart';
import 'login_screen.dart';

/// Meus dados, meus cães, plano premium, sair e excluir conta.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _me;
  List<Dog> _dogs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await Api.instance.get('/me');
      final dogs = (await Api.instance.get('/dogs/mine') as List).map((j) => Dog.fromJson(j)).toList();
      if (!mounted) return;
      setState(() {
        _me = me;
        _dogs = dogs;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _openDogForm([Dog? dog]) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => DogFormScreen(dog: dog)));
    if (changed == true) _load();
  }

  Future<void> _removeDog(Dog dog) async {
    final ok = await _confirm(
      'Remover ${dog.name}?',
      'O cão sai do seu perfil, mas continua no histórico (por segurança).',
    );
    if (!ok) return;
    try {
      await Api.instance.delete('/dogs/${dog.id}');
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _setPremium(bool value) async {
    try {
      final me = await Api.instance.put('/me/premium', {'premium': value});
      setState(() => _me = me);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _logout() async {
    await Api.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  Future<void> _deleteAccount() async {
    final ok = await _confirm(
      'Excluir minha conta?',
      'Seus dados pessoais serão apagados (LGPD). Essa ação não pode ser desfeita.',
    );
    if (!ok) return;
    try {
      await Api.instance.delete('/me');
      await _logout();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<bool> _confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final me = _me;
    final current = _dogs.where((d) => !d.removed).toList();
    final past = _dogs.where((d) => d.removed).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [IconButton(icon: const Icon(Icons.logout), tooltip: 'Sair', onPressed: _logout)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDogForm(),
        icon: const Icon(Icons.add),
        label: const Text('Cadastrar cão'),
      ),
      body: me == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Constrained(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(me['name'], style: Theme.of(context).textTheme.titleLarge),
                      subtitle: Text('${me['email']}\n${me['city']}'),
                      isThreeLine: true,
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.workspace_premium),
                      title: const Text('All Love Premium'),
                      subtitle: const Text('Sem anúncios'),
                      value: me['is_premium'] == true,
                      onChanged: _setPremium,
                    ),
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Meus cães', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                    if (current.isEmpty)
                      const Padding(padding: EdgeInsets.all(16), child: Text('Você ainda não cadastrou nenhum cão.')),
                    for (final d in current)
                      ListTile(
                        leading: DogAvatar(photoUrl: d.photoUrl),
                        title: Text('${d.name} • ${d.ageText}'),
                        subtitle: Text(
                          d.vaccineStatus.description,
                          style: TextStyle(
                            color: d.vaccineStatus.upToDate
                                ? successColor(context)
                                : Theme.of(context).colorScheme.error,
                          ),
                        ),
                        onTap: () async {
                          await Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => DogDetailScreen(dogId: d.id)));
                          _load();
                        },
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) => v == 'edit' ? _openDogForm(d) : _removeDog(d),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Editar')),
                            PopupMenuItem(value: 'remove', child: Text('Remover')),
                          ],
                        ),
                      ),
                    if (past.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Text('Cães que já tive', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      for (final d in past)
                        ListTile(
                          leading: DogAvatar(photoUrl: d.photoUrl),
                          title: Text(d.name),
                          subtitle: Text(d.breed),
                          onTap: () =>
                              Navigator.of(context)
                                  .push(MaterialPageRoute(builder: (_) => DogDetailScreen(dogId: d.id))),
                        ),
                    ],
                    const Divider(),
                    ListTile(
                      leading: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
                      title: const Text('Excluir minha conta'),
                      onTap: _deleteAccount,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
