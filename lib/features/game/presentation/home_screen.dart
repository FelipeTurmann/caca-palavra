import 'package:flutter/material.dart';
import '../../../core/theme/game_theme.dart';
import 'game_controller.dart';

class WalletBadge extends StatelessWidget {
  const WalletBadge({super.key, required this.balance});
  final int balance;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$balance moedas',
    excludeSemantics: true,
    child: Chip(
      avatar: const Icon(
        Icons.monetization_on_rounded,
        color: Color(0xFFAE7412),
      ),
      label: Text('$balance moedas'),
    ),
  );
}

class SaveStatus extends StatelessWidget {
  const SaveStatus({super.key, required this.controller});
  final GameController controller;
  @override
  Widget build(BuildContext context) {
    if (controller.saveError != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            controller.saveError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          TextButton(
            onPressed: controller.busy ? null : controller.retrySave,
            child: const Text('Tentar novamente'),
          ),
        ],
      );
    }
    if (controller.busy) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: LinearProgressIndicator(semanticsLabel: 'Salvando progresso'),
      );
    }
    return const SizedBox.shrink();
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller, required this.onPlay});
  final GameController controller;
  final VoidCallback onPlay;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final profile = controller.coordinator!.profile;
      final label = profile.pendingCompletion != null
          ? 'Ver resultado · Nível ${profile.currentLevelId}'
          : profile.hasStarted
          ? 'Continuar · Nível ${profile.currentLevelId}'
          : 'Jogar';
      return Scaffold(
        backgroundColor: GameTheme.cream,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            color: GameTheme.teal,
                            size: 64,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Conecte palavras',
                            style: Theme.of(context).textTheme.headlineMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Ligue as letras. Descubra novas palavras.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          WalletBadge(balance: profile.balance),
                          Text(
                            '${profile.completed.length} de ${profile.catalogIds.length} níveis concluídos',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),
                          if (profile.campaignComplete) ...[
                            Text(
                              'Campanha concluída!',
                              style: Theme.of(context).textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Você descobriu todas as palavras desta coleção. Novos níveis chegarão em breve.',
                              textAlign: TextAlign.center,
                            ),
                          ] else
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                key: const ValueKey('play'),
                                onPressed:
                                    controller.busy ||
                                        controller.saveError != null
                                    ? null
                                    : onPlay,
                                child: Text(label, textAlign: TextAlign.center),
                              ),
                            ),
                          SaveStatus(controller: controller),
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
    },
  );
}
