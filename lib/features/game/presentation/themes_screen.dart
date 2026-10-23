import 'package:flutter/material.dart';
import '../../../core/preferences/player_preferences.dart';
import '../../../core/theme/game_theme.dart';
import '../../../core/theme/visual_theme_catalog.dart';
import '../../../core/widgets/garden.dart';
import 'game_controller.dart';

Future<void> openThemes(BuildContext context, GameController controller) async {
  if (controller.themesOpen || controller.settingsOpen || controller.shopOpen) {
    return;
  }
  controller.themesOpen = true;
  controller.cancelTransientPresentation();
  try {
    await controller.waitIdle();
    await controller.refreshCalendar();
    if (!context.mounted) return;
    controller.preferences.clearThemeNotice();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (_) => FractionallySizedBox(
        heightFactor: .94,
        child: ThemesScreen(controller: controller),
      ),
    );
    await controller.preferences.flush();
    await controller.refreshCalendar();
  } finally {
    controller.themesOpen = false;
    controller.refresh();
  }
}

class ThemesScreen extends StatelessWidget {
  const ThemesScreen({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller.preferences,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Temas'),
        leading: IconButton(
          tooltip: 'Fechar temas',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: ThemeSaveFeedback(
          preferences: controller.preferences,
          showSuccess: true,
        ),
      ),
      body: Garden(
        quiet: true,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Escolha o visual do seu jogo. Seu progresso continua o mesmo.',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns =
                            constraints.maxWidth >= 640 &&
                            MediaQuery.textScalerOf(context).scale(16) <= 24;
                        final cards = [
                          for (final theme in VisualTheme.values)
                            _ThemeOption(
                              theme: theme,
                              preferences: controller.preferences,
                            ),
                        ];
                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            for (final card in cards)
                              SizedBox(
                                width: columns
                                    ? (constraints.maxWidth - 16) / 2
                                    : constraints.maxWidth,
                                child: card,
                              ),
                          ],
                        );
                      },
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
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({required this.theme, required this.preferences});
  final VisualTheme theme;
  final PreferencesController preferences;
  @override
  Widget build(BuildContext context) {
    final selected = preferences.value.visualTheme == theme;
    return GardenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ThemePreview(theme: theme),
          const SizedBox(height: 16),
          Text(theme.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (selected)
            Semantics(
              selected: true,
              label: '${theme.title}. Em uso',
              excludeSemantics: true,
              child: const SizedBox(
                height: 52,
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: GameTheme.teal),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Em uso',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Semantics(
              label: 'Usar tema ${theme.title}',
              button: true,
              onTap: () => preferences.selectTheme(theme),
              excludeSemantics: true,
              child: FilledButton(
                key: ValueKey('use-theme-${theme.id}'),
                onPressed: () => preferences.selectTheme(theme),
                child: const Text('Usar tema'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Thumbnail composed from the same local art as the theme itself.
class ThemePreview extends StatelessWidget {
  const ThemePreview({super.key, required this.theme});
  final VisualTheme theme;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: VisualThemeScope(
          theme: theme,
          child: Garden(
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 5),
                child: ThemeMascot(theme: theme, height: 127),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class ThemeSaveFeedback extends StatelessWidget {
  const ThemeSaveFeedback({
    super.key,
    required this.preferences,
    this.showSuccess = false,
  });
  final PreferencesController preferences;
  final bool showSuccess;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: preferences,
    builder: (context, _) {
      final message =
          preferences.error ??
          (preferences.savingTheme
              ? 'Salvando tema…'
              : showSuccess && preferences.themeSaved
              ? 'Tema aplicado'
              : null);
      if (message == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(message, textAlign: TextAlign.center),
            ),
            if (preferences.error != null)
              TextButton(
                onPressed: preferences.retry,
                child: const Text('Tentar novamente'),
              ),
          ],
        ),
      );
    },
  );
}
