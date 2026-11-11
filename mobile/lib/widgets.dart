import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'api.dart';
import 'screens/login_screen.dart';

/// Mostra o erro numa barra embaixo da tela. Se a sessão caiu ou a conta foi
/// bloqueada, volta para o login.
void showError(BuildContext context, Object error) {
  if (!context.mounted) return;
  final message = error.toString();
  if (error is ApiException && (error.status == 401 || message.startsWith('Conta bloqueada'))) {
    Api.instance.forgetToken();
    Navigator.of(context)
        .pushAndRemoveUntil(MaterialPageRoute(builder: (_) => LoginScreen(initialMessage: message)), (_) => false);
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

void showMessage(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Pede permissão, lê o GPS e envia a posição para a API.
Future<Position?> updateMyLocation(BuildContext context) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Ligue a localização do aparelho';
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw 'Permita o acesso à localização para ver quem está por perto';
    }
    final pos = await Geolocator.getCurrentPosition();
    await Api.instance.put('/me/location', {'lat': pos.latitude, 'lng': pos.longitude});
    return pos;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return null;
  }
}

/// "Deu certo" em azul: o cão não enxerga verde.
Color successColor(BuildContext context) => Theme.of(context).colorScheme.primary;
Color successContainer(BuildContext context) => Theme.of(context).colorScheme.primaryContainer;

/// Formas do Material 3 Expressive (cookie, flor e "blob").
abstract final class Shapes {
  static const cookie9 = StarBorder(points: 9, innerRadiusRatio: 0.84, pointRounding: 0.5, valleyRounding: 0.5);
  static const cookie12 = StarBorder(points: 12, innerRadiusRatio: 0.88, pointRounding: 0.5, valleyRounding: 0.5);
  static const flower = StarBorder(points: 6, innerRadiusRatio: 0.72, pointRounding: 0.7, valleyRounding: 0.3);
  static const blob = StarBorder(
    points: 3,
    innerRadiusRatio: 0.78,
    pointRounding: 0.5,
    valleyRounding: 0.5,
    rotation: 20,
  );
  static const all = [cookie9, flower, cookie12, blob];
}

/// Recorta o filho numa forma expressiva.
class Shaped extends StatelessWidget {
  const Shaped({super.key, required this.shape, required this.child, this.size});
  final ShapeBorder shape;
  final Widget child;
  final double? size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      child: child,
    ),
  );
}

/// Foto (ou pata) do cão recortada numa forma, usada em stories e cartões.
class ShapedDog extends StatelessWidget {
  const ShapedDog({super.key, required this.photoUrl, required this.shape, this.size = 72});
  final String? photoUrl;
  final ShapeBorder shape;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = Api.imageUrl(photoUrl);
    final paw = Icon(Icons.pets, size: size * 0.45, color: scheme.onPrimaryContainer);
    return Shaped(
      shape: shape,
      size: size,
      child: ColoredBox(
        color: scheme.primaryContainer,
        child: url == null
            ? Center(child: paw)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(child: paw),
              ),
      ),
    );
  }
}

class DogAvatar extends StatelessWidget {
  const DogAvatar({super.key, required this.photoUrl, this.radius = 24});
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = Api.imageUrl(photoUrl);
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      backgroundImage: url == null ? null : NetworkImage(url),
      onBackgroundImageError: url == null ? null : (_, _) {},
      child: url == null ? Icon(Icons.pets, size: radius) : null,
    );
  }
}

/// Foto grande do cão (ou um ícone, se não houver foto).
class DogPhoto extends StatelessWidget {
  const DogPhoto({super.key, required this.photoUrl, this.height = 260});
  final String? photoUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    final url = Api.imageUrl(photoUrl);
    return Container(
      height: height,
      width: double.infinity,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: url == null
          ? Icon(Icons.pets, size: height / 3, color: Theme.of(context).colorScheme.onPrimaryContainer)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.pets, size: height / 3, color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
    );
  }
}

/// Anúncio de patrocinador. Não aparece para usuários premium.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  Map<String, dynamic>? _ad;

  @override
  void initState() {
    super.initState();
    Api.instance
        .get('/ads/random')
        .then((data) {
          if (mounted) setState(() => _ad = data['ad']);
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Card.filled(
      color: scheme.tertiaryContainer,
      margin: const EdgeInsets.all(8),
      child: ListTile(
        iconColor: scheme.onTertiaryContainer,
        textColor: scheme.onTertiaryContainer,
        leading: const Icon(Icons.storefront),
        title: Text(ad['sponsor']),
        subtitle: Text(ad['message']),
        trailing: Text('Anúncio', style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}

/// Centraliza o conteúdo e limita a largura em tablets.
class Constrained extends StatelessWidget {
  const Constrained({super.key, required this.child, this.maxWidth = 640});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}
