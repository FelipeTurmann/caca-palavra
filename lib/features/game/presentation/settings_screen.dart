import 'package:flutter/material.dart';
import '../../../core/widgets/garden.dart';
import '../../../core/widgets/game_loading.dart';
import '../../../core/widgets/motion_policy.dart';
import 'game_controller.dart';
import 'tutorial_screen.dart';
import 'account_screen.dart';

Future<void> openSettings(
  BuildContext context,
  GameController controller,
) async {
  if (controller.settingsOpen || controller.shopOpen || controller.themesOpen) {
    return;
  }
  controller.settingsOpen = true;
  controller.cancelTransientPresentation();
  var sessionChanged = false;
  try {
    await controller.waitIdle();
    await controller.refreshCalendar();
    if (!context.mounted ||
        (controller.saveError != null &&
            controller.coordinator?.online == null)) {
      return;
    }
    sessionChanged =
        await showModalBottomSheet<bool>(
          context: context,
          isDismissible: false,
          enableDrag: false,
          sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
              ? AnimationStyle.noAnimation
              : null,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => FractionallySizedBox(
            heightFactor: .94,
            child: SettingsScreen(controller: controller),
          ),
        ) ==
        true;
    await controller.preferences.flush();
    if (!sessionChanged) await controller.refreshCalendar();
  } finally {
    controller.settingsOpen = false;
    controller.refresh();
  }
  if (sessionChanged && context.mounted) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    await controller.onSessionChanged?.call();
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});
  final GameController controller;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool accountBusy = false;
  String? loadingMessage;
  GameController get controller => widget.controller;
  @override
  Widget build(BuildContext context) {
    final preferences = controller.preferences;
    return ListenableBuilder(
      listenable: preferences,
      builder: (context, _) {
        final value = preferences.value;
        final system = MotionPolicy.systemOf(context);
        final locked =
            accountBusy ||
            controller
                    .coordinator
                    ?.online
                    ?.session
                    .googleOperation?['started'] ==
                true;
        return GameLoadingOverlay(
          message: loadingMessage,
          child: PopScope(
            canPop: !locked,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Configurações'),
                leading: IconButton(
                  tooltip: 'Fechar configurações',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: locked ? null : () => Navigator.pop(context),
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
                          if (controller.coordinator?.online != null) ...[
                            PlayerAccountCard(
                              controller: controller,
                              onBusyChanged: (value) =>
                                  setState(() => accountBusy = value),
                              onLoadingChanged: (value) =>
                                  setState(() => loadingMessage = value),
                              onSessionChanged: () =>
                                  Navigator.pop(context, true),
                            ),
                            const SizedBox(height: 16),
                          ],
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
                                  onChanged: (v) => preferences.update(
                                    value.copyWith(sound: v),
                                  ),
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
                            onPressed: locked
                                ? null
                                : () async {
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
    style: IconButton.styleFrom(
      backgroundColor: const Color(0xF7FFF9EE),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      side: const BorderSide(color: Color(0xFFEED6AE)),
    ),
  );
}
