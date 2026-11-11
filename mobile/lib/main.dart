import 'package:flutter/material.dart';

import 'api.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

/// Cor semente do Material 3: o azul fraquinho pedido pelo cliente.
/// Todo o esquema de cores (claro e escuro) é gerado a partir dela.
/// (Curiosidade: cães enxergam bem tons de azul e amarelo.)
const allLoveSeed = Color(0xFF7EB6E6);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.instance.loadToken();
  runApp(const AllLoveApp());
}

ThemeData _theme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: allLoveSeed, brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
      scrolledUnderElevation: 3,
    ),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    cardTheme: const CardThemeData(clipBehavior: Clip.antiAlias),
    chipTheme: const ChipThemeData(side: BorderSide.none),
    // Botões maiores: o cliente quer que qualquer pessoa consiga usar.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(64, 52), textStyle: const TextStyle(fontSize: 16)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

class AllLoveApp extends StatelessWidget {
  const AllLoveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'All Love',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: Api.instance.loggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
