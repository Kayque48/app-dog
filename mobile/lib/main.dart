import 'package:flutter/material.dart';

import 'api.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

/// Tema do All Love: Material 3 Expressive com as cores que um cachorro enxerga.
///
/// Cães são dicromatas: só têm cones sensíveis ao azul-violeta e ao amarelo.
/// Vermelho e verde viram um marrom acinzentado para eles, então a paleta usa
/// só azul, amarelo, violeta e neutros, inclusive para erro (amarelo) e sucesso (azul).
/// O azul fraquinho pedido pelo cliente continua como "primaryContainer".
const dogLight = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF2A4BDB),
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFDBE2FF),
  onPrimaryContainer: Color(0xFF001566),
  secondary: Color(0xFF6B5600),
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFFFD83D),
  onSecondaryContainer: Color(0xFF231B00),
  tertiary: Color(0xFF5C4FD6),
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFFE4DFFF),
  onTertiaryContainer: Color(0xFF180A6B),
  error: Color(0xFF7A5C00),
  onError: Colors.white,
  errorContainer: Color(0xFFFFE27A),
  onErrorContainer: Color(0xFF261A00),
  surface: Color(0xFFF8F9FF),
  onSurface: Color(0xFF11152B),
  onSurfaceVariant: Color(0xFF454A63),
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: Color(0xFFF1F3FF),
  surfaceContainer: Color(0xFFE9ECFB),
  surfaceContainerHigh: Color(0xFFE2E6F8),
  surfaceContainerHighest: Color(0xFFDBE0F4),
  outline: Color(0xFF747A96),
  outlineVariant: Color(0xFFC4C8E0),
  inverseSurface: Color(0xFF262B45),
  onInverseSurface: Color(0xFFEEF0FF),
  inversePrimary: Color(0xFFB6C4FF),
);

const dogDark = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFB6C4FF),
  onPrimary: Color(0xFF00228F),
  primaryContainer: Color(0xFF1F3BBF),
  onPrimaryContainer: Color(0xFFDBE2FF),
  secondary: Color(0xFFFFD83D),
  onSecondary: Color(0xFF3A2F00),
  secondaryContainer: Color(0xFF574500),
  onSecondaryContainer: Color(0xFFFFE27A),
  tertiary: Color(0xFFC7BFFF),
  onTertiary: Color(0xFF2A1A99),
  tertiaryContainer: Color(0xFF4336B8),
  onTertiaryContainer: Color(0xFFE4DFFF),
  error: Color(0xFFFFD83D),
  onError: Color(0xFF3A2F00),
  errorContainer: Color(0xFF574500),
  onErrorContainer: Color(0xFFFFE27A),
  surface: Color(0xFF0C1030),
  onSurface: Color(0xFFE2E4FF),
  onSurfaceVariant: Color(0xFFC4C8E0),
  surfaceContainerLowest: Color(0xFF070A22),
  surfaceContainerLow: Color(0xFF141A3D),
  surfaceContainer: Color(0xFF191F44),
  surfaceContainerHigh: Color(0xFF232A52),
  surfaceContainerHighest: Color(0xFF2E355F),
  outline: Color(0xFF8E93B0),
  outlineVariant: Color(0xFF454A63),
  inverseSurface: Color(0xFFE2E4FF),
  onInverseSurface: Color(0xFF262B45),
  inversePrimary: Color(0xFF2A4BDB),
);

/// Amarelo da curtida: a cor mais chamativa para o cão (e para nós).
const likeYellow = Color(0xFFF5B700);

const displayFont = 'Bricolage Grotesque';

/// Estilo dos títulos grandes (fonte variável, peso extra-negrito).
TextStyle? display(TextStyle? base, {double weight = 800}) => base?.copyWith(
  fontFamily: displayFont,
  fontVariations: [FontVariation('wght', weight)],
  letterSpacing: -0.5,
  height: 1.05,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.instance.loadToken();
  runApp(const AllLoveApp());
}

ThemeData _theme(ColorScheme scheme) {
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final t = base.textTheme;
  return base.copyWith(
    textTheme: t.copyWith(
      displayLarge: display(t.displayLarge),
      displayMedium: display(t.displayMedium),
      displaySmall: display(t.displaySmall),
      headlineLarge: display(t.headlineLarge),
      headlineMedium: display(t.headlineMedium),
      headlineSmall: display(t.headlineSmall, weight: 750),
      titleLarge: display(t.titleLarge, weight: 700),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
      scrolledUnderElevation: 3,
      titleTextStyle: display(t.headlineMedium)?.copyWith(color: scheme.primary),
    ),
    inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
    cardTheme: CardThemeData(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    chipTheme: ChipThemeData(
      side: BorderSide.none,
      shape: const StadiumBorder(),
      backgroundColor: scheme.surfaceContainerHigh,
    ),
    // Botões grandes e em pílula (fáceis para qualquer pessoa).
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 52), shape: const StadiumBorder()),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.secondaryContainer,
      foregroundColor: scheme.onSecondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.secondaryContainer,
      height: 76,
    ),
    navigationRailTheme: NavigationRailThemeData(indicatorColor: scheme.secondaryContainer),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

class AllLoveApp extends StatelessWidget {
  const AllLoveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'All Love',
      debugShowCheckedModeBanner: false,
      theme: _theme(dogLight),
      darkTheme: _theme(dogDark),
      home: Api.instance.loggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
