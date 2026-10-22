import 'package:flutter/material.dart';
import '../../../../core/theme/game_theme.dart';
import '../game_controller.dart';
import 'ad_free_button.dart';

class AdFreePlanCard extends StatelessWidget {
  const AdFreePlanCard({super.key, required this.controller});
  final GameController controller;
  Future<void> _confirm(BuildContext context) async {
    final plan = controller.adFreePlan;
    if (plan.active || plan.busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Simular plano sem anúncios?'),
        content: const Text(
          'Compra única de R\$ 15,00, apenas como referência. '
          'Esta simulação não cobra dinheiro. O plano remove anúncios automáticos; '
          'os anúncios opcionais para ganhar moedas continuam disponíveis. '
          'Nesta versão ainda não há anúncios automáticos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('confirm-ad-free'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ativar simulação'),
          ),
        ],
      ),
    );
    if (confirmed == true) await plan.activateSimulated();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller.adFreePlan,
    builder: (context, _) {
      final plan = controller.adFreePlan;
      return Card(
        key: const ValueKey('ad-free-plan'),
        color: const Color(0xFFF1F7DE),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AdFreeIcon()),
              Text(
                'Sem anúncios',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text('Compra única · R\$ 15,00'),
              const SizedBox(height: 6),
              const Text(
                'Jogue sem anúncios automáticos. Os anúncios opcionais '
                'para ganhar moedas continuam disponíveis.',
              ),
              const SizedBox(height: 6),
              const Text(
                'Simulação sem cobrança real.',
                style: TextStyle(
                  color: GameTheme.teal,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              if (plan.active)
                Semantics(
                  liveRegion: true,
                  child: const Text(
                    'Plano ativado (simulação)',
                    key: ValueKey('ad-free-active'),
                    style: TextStyle(
                      color: GameTheme.teal,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                FilledButton(
                  key: const ValueKey('activate-ad-free'),
                  onPressed:
                      plan.busy ||
                          controller.busy ||
                          controller.saveError != null
                      ? null
                      : () => _confirm(context),
                  child: Text(
                    plan.busy ? 'Salvando…' : 'Simular compra · R\$ 15,00',
                  ),
                ),
              if (plan.error != null)
                Semantics(liveRegion: true, child: Text(plan.error!)),
            ],
          ),
        ),
      );
    },
  );
}
