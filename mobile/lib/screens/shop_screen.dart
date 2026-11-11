import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../main.dart' show display, likeYellow;
import '../models.dart';
import '../widgets.dart';

/// Loja: catálogo dos pet shops parceiros. A compra é combinada direto com o pet shop.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String _category = '';
  List<Map<String, dynamic>>? _products;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = List<Map<String, dynamic>>.from(await Api.instance.get('/products?category=$_category'));
      if (mounted) setState(() => _products = data);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _buy(Map<String, dynamic> p) {
    final link = p['link'] as String;
    final phone = p['provider_phone'] as String?;
    if (link.isNotEmpty) {
      launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    } else if (phone != null) {
      final text = Uri.encodeComponent('Oi! Quero o produto "${p['name']}" que vi no All Love 🐾');
      launchUrl(Uri.parse('https://wa.me/55$phone?text=$text'), mode: LaunchMode.externalApplication);
    }
  }

  static const _radii = [
    BorderRadius.only(
      topLeft: Radius.circular(32),
      topRight: Radius.circular(32),
      bottomRight: Radius.circular(64),
      bottomLeft: Radius.circular(8),
    ),
    BorderRadius.only(
      topLeft: Radius.circular(32),
      topRight: Radius.circular(32),
      bottomRight: Radius.circular(8),
      bottomLeft: Radius.circular(64),
    ),
    BorderRadius.all(Radius.circular(32)),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final products = _products;
    return Column(
      children: [
        SizedBox(
          height: 64,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            children: [
              for (final e in [MapEntry('', ('Tudo', Icons.apps)), ...productCategories.entries])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: _category == e.key,
                    avatar: Icon(e.value.$2, size: 18),
                    showCheckmark: false,
                    selectedColor: scheme.secondaryContainer,
                    label: Text(e.value.$1),
                    onSelected: (_) {
                      _category = e.key;
                      _load();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: products == null
              ? const Center(child: CircularProgressIndicator())
              : products.isEmpty
              ? const EmptyState(icon: Icons.inventory_2, text: 'Nada nesta categoria ainda.')
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.58,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, i) {
                    final p = products[i];
                    final cat = productCategories[p['category']]!;
                    return Container(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 1,
                            child: ClipRRect(
                              borderRadius: _radii[i % 3],
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ColoredBox(
                                    color: scheme.primaryContainer,
                                    child: Icon(cat.$2, size: 56, color: scheme.onPrimaryContainer),
                                  ),
                                  if (p['photo_url'] != null)
                                    Image.network(
                                      Api.imageUrl(p['photo_url'])!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const SizedBox(),
                                    ),
                                  Positioned(
                                    right: 6,
                                    bottom: 6,
                                    child: Shaped(
                                      shape: Shapes.cookie12,
                                      size: 76,
                                      child: ColoredBox(
                                        color: likeYellow,
                                        child: Center(
                                          child: Text(
                                            formatPrice(p['price_cents']),
                                            textAlign: TextAlign.center,
                                            style: display(const TextStyle(fontSize: 13, color: Color(0xFF231B00))),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cat.$1, style: Theme.of(context).textTheme.labelSmall),
                                  Text(
                                    p['name'],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: display(Theme.of(context).textTheme.titleMedium),
                                  ),
                                  const Spacer(),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                                      onPressed: () => _buy(p),
                                      icon: const Icon(Icons.shopping_bag, size: 18),
                                      label: const Text('Quero!'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
