import 'package:flutter/material.dart';
import '../../../core/widgets/garden.dart';
import '../../../core/widgets/motion_policy.dart';
import 'game_controller.dart';
import 'tutorial_screen.dart';

Future<void> openSettings(
  BuildContext context,
  GameController controller,
) async {
  if (controller.settingsOpen || controller.shopOpen) return;
  controller.settingsOpen = true;
  controller.cancelTransientPresentation();
  try {
    await controller.waitIdle();
    await controller.refreshCalendar();
    if (!context.mounted || controller.saveError != null) return;
    await showModalBottomSheet<void>(
      context: context,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .94,
        child: SettingsScreen(controller: controller),
      ),
    );
    await controller.preferences.flush();
    await controller.refreshCalendar();
  } finally {
    controller.settingsOpen = false;
    controller.refresh();
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final GameController controller;
  @override
  Widget build(BuildContext context) {
    final preferences = controller.preferences;
    return ListenableBuilder(
      listenable: preferences,
      builder: (context, _) {
        final value = preferences.value;
        final system = MotionPolicy.systemOf(context);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Configurações'),
            leading: IconButton(
              tooltip: 'Fechar configurações',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Garden(
            quiet: true,
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      GardenCard(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SwitchListTile(
                              key: const ValueKey('setting-sound'),
                              title: const Text('Efeitos sonoros'),
                              subtitle: const Text(
                                'Toques e sons suaves durante o jogo.',
                              ),
                              value: value.sound,
                              onChanged: (v) =>
                                  preferences.update(value.copyWith(sound: v)),
                            ),
                            SwitchListTile(
                              key: const ValueKey('setting-haptics'),
                              title: const Text('Vibração'),
                              subtitle: const Text(
                                'Pequenos pulsos ao selecionar e acertar.',
                              ),
                              value: value.haptics,
                              onChanged: (v) => preferences.update(
                                value.copyWith(haptics: v),
                              ),
                            ),
                            SwitchListTile(
                              key: const ValueKey('setting-motion'),
                              title: const Text('Reduzir animações'),
                              subtitle: Text(
                                system
                                    ? 'Redução ativa pelo sistema.'
                                    : 'Mantém as cores e os resultados, com menos movimento.',
                              ),
                              value: value.reduceMotion,
                              onChanged: (v) => preferences.update(
                                value.copyWith(reduceMotion: v),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      VolumeButton(
                        key: const ValueKey('review-tutorial'),
                        onPressed: () async {
                          controller.cancelGesture();
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TutorialScreen(
                                source: controller,
                                review: true,
                                onFinish: (_) async {
                                  Navigator.of(context).pop();
                                },
                              ),
                            ),
                          );
                          await controller.refreshCalendar();
                        },
                        child: const Text('Como jogar'),
                      ),
                      if (preferences.error != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: Text(preferences.error!),
                        ),
                        TextButton(
                          onPressed: preferences.retry,
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                      const SizedBox(height: 20),
                      const Text(
                        'Suas escolhas valem para a campanha, o desafio diário e a demonstração.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key, required this.controller});
  final GameController controller;
  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('settings'),
    tooltip: 'Configurações',
    onPressed: controller.busy || controller.saveError != null
        ? null
        : () => openSettings(context, controller),
    icon: const Icon(Icons.settings_rounded),
  );
}
