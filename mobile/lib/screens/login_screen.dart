import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart' show display, likeYellow;
import '../widgets.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialMessage});
  final String? initialMessage;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final msg = widget.initialMessage;
    if (msg != null) WidgetsBinding.instance.addPostFrameCallback((_) => showMessage(context, msg));
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      await Api.instance.login(_email.text.trim(), _password.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _deco(
    ShapeBorder shape,
    double size,
    Color color, {
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) => Positioned(
    left: left,
    top: top,
    right: right,
    bottom: bottom,
    child: Shaped(
      shape: shape,
      size: size,
      child: ColoredBox(color: color),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.primaryContainer,
      body: Stack(
        children: [
          // formas do Material 3 Expressive ao fundo
          _deco(Shapes.cookie9, 260, likeYellow, left: -70, top: -50),
          _deco(Shapes.flower, 180, scheme.primary, right: -40, top: 160),
          _deco(Shapes.blob, 150, scheme.tertiary, left: 20, bottom: 40),
          _deco(Shapes.cookie12, 110, scheme.onPrimaryContainer, right: 30, bottom: -30),
          SafeArea(
            child: Center(
              child: Constrained(
                maxWidth: 440,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                    decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(48)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Shaped(
                            shape: Shapes.cookie9,
                            size: 88,
                            child: const ColoredBox(
                              color: likeYellow,
                              child: Icon(Icons.pets, size: 44, color: Color(0xFF231B00)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'All Love',
                          textAlign: TextAlign.center,
                          style: display(Theme.of(context).textTheme.displayMedium)?.copyWith(color: scheme.primary),
                        ),
                        const Text('A rede social dos cachorros', textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.email)),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          onSubmitted: (_) => _login(),
                          decoration: const InputDecoration(labelText: 'Senha', prefixIcon: Icon(Icons.lock)),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _loading ? null : _login,
                          child: Text(_loading ? 'Entrando...' : 'Entrar'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                          child: const Text('Não tem conta? Cadastre-se'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
