import 'package:flutter/material.dart';
import '../../../core/widgets/garden.dart';
import '../application/game_session_coordinator.dart';
import '../application/shop_models.dart';
import '../../../core/theme/game_theme.dart';
import 'game_controller.dart';
import 'home_screen.dart';
import 'widgets/ad_free_plan_card.dart';

Future<void> openShop(BuildContext context, GameController controller) async {
  if (controller.shopOpen || controller.themesOpen) return;
  controller.shopOpen = true;
  controller.cancelTransientPresentation();
  try {
    await controller.waitIdle();
    await controller.adFreePlan.flush();
    await controller.refreshCalendar();
    if (!context.mounted || controller.saveError != null) return;
    controller.creditMessage = null;
    await showModalBottomSheet<void>(
      context: context,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.95,
        child: ShopScreen(controller: controller),
      ),
    );
    await controller.adFreePlan.flush();
    await controller.refreshCalendar();
  } finally {
    controller.shopOpen = false;
    controller.refresh();
  }
}

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key, required this.controller});
  final GameController controller;
  Future<void> purchase(BuildContext context, CoinPackage package) async {
    final id = operationId('purchase');
    final ok = await showDialog<bool>(
      context: context,
      animationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Simular compra?'),
        content: Text(
          '${package.amount} moedas · ${package.price} (preço de referência). Esta é uma simulação, sem cobrança real.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('confirm-package'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simular compra'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await controller.credit(
        () => controller.coordinator!.simulatePurchase(package.id, id: id),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, controller.adFreePlan]),
    builder: (context, _) => PopScope<void>(
      canPop:
          !controller.busy &&
          !controller.adFreePlan.busy &&
          controller.saveError == null,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          await controller.waitIdle();
          await controller.adFreePlan.flush();
          if (context.mounted && controller.saveError == null) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: GameTheme.cream,
        appBar: AppBar(
          title: const Text('Loja'),
          leading: IconButton(
            tooltip: 'Fechar loja',
            onPressed: () async {
              await controller.waitIdle();
              await controller.adFreePlan.flush();
              if (context.mounted && controller.saveError == null) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        body: Garden(
          quiet: true,
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Loja em teste: compras simuladas, sem cobrança real.',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: WalletBadge(balance: controller.balance),
                      ),
                      SaveStatus(controller: controller),
                      if (controller.creditMessage != null)
                        Semantics(
                          liveRegion: true,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              controller.creditMessage!,
                              key: const ValueKey('credit-confirmation'),
                              style: const TextStyle(
                                color: GameTheme.teal,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      AdFreePlanCard(controller: controller),
                      const SizedBox(height: 12),
                      for (final package in ShopCatalog.packages)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Icon(
                                  Icons.monetization_on_rounded,
                                  size: 32,
                                  color: Color(0xFFAE7412),
                                ),
                                Text(
                                  '${package.amount} moedas',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Text('${package.price} · preço de referência'),
                                const SizedBox(height: 8),
                                VolumeButton(
                                  key: ValueKey(package.id),
                                  onPressed:
                                      controller.busy ||
                                          controller.saveError != null
                                      ? null
                                      : () => purchase(context, package),
                                  child: const Text('Selecionar pacote'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: ValueKey(
                          controller.coordinator!.usesAdMobTestAds
                              ? 'rewarded-ad'
                              : 'simulated-ad',
                        ),
                        onPressed:
                            controller.busy || controller.saveError != null
                            ? null
                            : () => controller.credit(
                                () => controller.coordinator!.watchRewardAd(),
                              ),
                        icon: const Icon(Icons.play_circle_outline_rounded),
                        label: Text(
                          controller.busy
                              ? 'Aguarde…'
                              : 'Assistir anúncio · +15 moedas',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Text(
                        controller.coordinator!.usesAdMobTestAds
                            ? 'Anúncio de teste do Google AdMob, sem receita real. '
                                  'Receba 15 moedas ao concluir a recompensa.'
                            : 'Simulação: as moedas são concedidas sem exibir vídeo.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
