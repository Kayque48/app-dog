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

/// Cor de "deu certo" (o Material 3 não tem uma cor de sucesso no esquema padrão).
Color successColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA3D69F) : const Color(0xFF2E6B30);
Color successContainer(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1D5220) : const Color(0xFFC8F0C4);

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
          : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.broken_image)),
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
