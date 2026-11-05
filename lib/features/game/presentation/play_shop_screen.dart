import 'package:flutter/material.dart';

import '../application/play_shop.dart';
import 'game_controller.dart';
import 'home_screen.dart';

class PlayShopScreen extends StatelessWidget {
  const PlayShopScreen({
    super.key,
    required this.controller,
    required this.shop,
  });

  final GameController controller;
  final PlayShop shop;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, shop]),
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Loja')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: WalletBadge(balance: controller.balance),
            ),
            if (shop.loading) const LinearProgressIndicator(),
            if (shop.message case final message?)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(message),
                ),
              ),
            if (controller.adFreePlan.active)
              const ListTile(
                leading: Icon(Icons.check_circle_outline),
                title: Text('Sem anúncios ativo'),
              ),
            for (final offer in shop.offers)
              if (!offer.adFree || !controller.adFreePlan.active)
                Card(
                  child: ListTile(
                    leading: Icon(
                      offer.adFree
                          ? Icons.block
                          : Icons.monetization_on_outlined,
                    ),
                    title: Text(offer.name),
                    subtitle: offer.adFree
                        ? const Text(
                            'Compra única. Remove anúncios automáticos.',
                          )
                        : null,
                    trailing: FilledButton(
                      onPressed:
                          shop.busy ||
                              shop.loading ||
                              controller.busy ||
                              controller.saveError != null ||
                              controller.connectionBlocked
                          ? null
                          : () => shop.buy(offer),
                      child: Text(offer.details.price),
                    ),
                  ),
                ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: shop.loading
                  ? null
                  : shop.enabled && shop.offers.isNotEmpty
                  ? shop.restore
                  : shop.prepare,
              child: Text(
                shop.enabled && shop.offers.isNotEmpty
                    ? 'Verificar compras'
                    : 'Atualizar loja',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
