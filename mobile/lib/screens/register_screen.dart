import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';
import 'home_screen.dart';

/// Cadastro do dono. CPF, telefone e endereço são obrigatórios por segurança.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _cpf = TextEditingController();
  final _cep = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  bool _terms = false;
  bool _loading = false;

  /// Preenche cidade e endereço a partir do CEP.
  Future<void> _fillFromCep() async {
    final data = await lookupCep(_cep.text);
    if (data == null || !mounted) return;
    setState(() {
      _city.text = '${data['localidade']} - ${data['uf']}';
      _address.text = '${data['logradouro']}, nº , ${data['bairro']}';
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_terms) {
      showMessage(context, 'Aceite os termos de uso e a política de privacidade');
      return;
    }
    setState(() => _loading = true);
    try {
      await Api.instance.register({
        'name': _name.text,
        'email': _email.text,
        'password': _password.text,
        'phone': _phone.text,
        'cpf': _cpf.text,
        'cep': _cep.text,
        'city': _city.text,
        'address': _address.text,
        'accepted_terms': _terms,
      });
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null;

  Widget _field(TextEditingController c, String label,
          {TextInputType? type, bool obscure = false, String? hint, ValueChanged<String>? onChanged}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          keyboardType: type,
          obscureText: obscure,
          validator: _required,
          onChanged: onChanged,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: Constrained(
        maxWidth: 520,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Seus dados ficam protegidos e só a moderação vê CPF, telefone e endereço. '
                  'Eles servem para a segurança de todos os donos e cães.'),
              const SizedBox(height: 16),
              _field(_name, 'Nome completo'),
              _field(_email, 'E-mail', type: TextInputType.emailAddress),
              _field(_password, 'Senha (mínimo 6 caracteres)', obscure: true),
              _field(_phone, 'Telefone com DDD', type: TextInputType.phone, hint: '(11) 91234-5678'),
              _field(_cpf, 'CPF', type: TextInputType.number, hint: '000.000.000-00'),
              _field(_cep, 'CEP', type: TextInputType.number, onChanged: (v) {
                if (v.replaceAll(RegExp(r'\D'), '').length == 8) _fillFromCep();
              }),
              _field(_city, 'Cidade'),
              _field(_address, 'Endereço (rua, número, bairro)'),
              CheckboxListTile(
                value: _terms,
                onChanged: (v) => setState(() => _terms = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Li e aceito os termos de uso e a política de privacidade (LGPD)'),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loading ? null : _submit, child: Text(_loading ? 'Enviando...' : 'Criar conta')),
            ],
          ),
        ),
      ),
    );
  }
}
