import 'package:flutter/material.dart';

import 'api.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

/// Cores pedidas pelo cliente: azul fraquinho e branco.
/// (Curiosidade: cães enxergam bem tons de azul e amarelo.)
const allLoveBlue = Color(0xFF7EB6E6);
const allLoveBlueDark = Color(0xFF3C7DB8);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.instance.loadToken();
  runApp(const AllLoveApp());
}

class AllLoveApp extends StatelessWidget {
  const AllLoveApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: allLoveBlue,
      primary: allLoveBlueDark,
      surface: Colors.white,
    );
    return MaterialApp(
      title: 'All Love',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(backgroundColor: allLoveBlue, foregroundColor: Colors.white, centerTitle: true),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
        // Botões e textos maiores: o cliente quer que qualquer pessoa consiga usar.
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 52), textStyle: const TextStyle(fontSize: 17)),
        ),
        textTheme: Typography.blackMountainView.apply(fontSizeFactor: 1.05),
      ),
      home: Api.instance.loggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
