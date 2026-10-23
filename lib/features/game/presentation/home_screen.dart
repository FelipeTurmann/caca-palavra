import 'package:flutter/material.dart';
import '../../../core/widgets/garden.dart';
import 'settings_screen.dart';
import '../../../core/theme/game_theme.dart';
import 'game_controller.dart';
import 'shop_screen.dart';
import 'themes_screen.dart';
import '../../../core/theme/visual_theme_catalog.dart';
import 'widgets/home_art.dart';
import 'dart:math' as math;

class WalletBadge extends StatelessWidget {
  const WalletBadge({super.key, required this.balance, this.onPressed});
  final VoidCallback? onPressed;
  final int balance;
  @override
  Widget build(BuildContext context) => Semantics(
    label: onPressed == null
        ? '$balance moedas'
        : '$balance moedas. Abrir loja',
    button: onPressed != null,
    onTap: onPressed,
    excludeSemantics: true,
    child: onPressed != null
        ? ActionChip(
            onPressed: onPressed,
            avatar: Icon(
              VisualThemeScope.of(context).isLagoon
                  ? Icons.stars_rounded
                  : Icons.monetization_on_rounded,
              color: VisualThemeScope.of(context).isLagoon
                  ? const Color(0xFFE6A11B)
                  : const Color(0xFFAE7412),
            ),
            label: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 280),
              child: Text('$balance moedas', key: ValueKey(balance)),
            ),
          )
        : Chip(
            avatar: Icon(
              VisualThemeScope.of(context).isLagoon
                  ? Icons.stars_rounded
                  : Icons.monetization_on_rounded,
              color: VisualThemeScope.of(context).isLagoon
                  ? const Color(0xFFE6A11B)
                  : const Color(0xFFAE7412),
            ),
            label: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 280),
              child: Text('$balance moedas', key: ValueKey(balance)),
            ),
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
  const HomeScreen({
    super.key,
    required this.controller,
    required this.onPlay,
    this.onDaily,
  });
  final VoidCallback? onDaily;
  final GameController controller;
  final VoidCallback onPlay;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final profile = controller.coordinator!.profile;
      final coordinator = controller.coordinator!;
      final label = profile.pendingCompletion != null
          ? 'Ver resultado · Nível ${profile.currentLevelId}'
          : profile.hasStarted
          ? 'Continuar · Nível ${profile.currentLevelId}'
          : 'Jogar';
      final enabled = !controller.busy && controller.saveError == null;
      final day = coordinator.todayProgress;
      final dailyComplete =
          day?.completed == true && day?.pendingResult == false;
      final dailySubtitle = coordinator.clockReversed
          ? 'Ajuste a data do aparelho para acessar o desafio diário.'
          : dailyComplete
          ? 'Desafio de hoje concluído'
          : day?.pendingResult == true
          ? 'Ver resultado do desafio'
          : day != null
          ? 'Continuar · ${day.round.targets.length} de ${day.definition.words.length} palavras'
          : 'Um novo desafio por dia';
      return Scaffold(
        body: HomeLandscape(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth >= 800 &&
                    constraints.maxWidth > constraints.maxHeight;
                final scale = MediaQuery.textScalerOf(context).scale(1);
                final width = math.min(
                  wide ? 440.0 : 460.0,
                  constraints.maxWidth - 40,
                );
                final fontSize = math.min(60.0, width * .17);
                final artHeight = math.min(
                  width * .63,
                  math.max(140.0, constraints.maxHeight * .28),
                );
                final brand = Semantics(
                  label: 'Conecte palavras',
                  header: true,
                  excludeSemantics: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Conecte',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: fontSize,
                          height: .97,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                          color: GameTheme.ink,
                          shadows: const [
                            Shadow(
                              color: Color(0x1F123B49),
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          'palavras',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: fontSize,
                            height: .97,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -2,
                            color: const Color(0xFFFF675F),
                            shadows: const [
                              Shadow(
                                color: Color(0x27D6493E),
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                final hero = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    brand,
                    if (scale <= 1.3) ...[
                      const SizedBox(height: 8),
                      HomeWordGarden(height: artHeight, fullBleed: !wide),
                    ],
                  ],
                );
                final cards = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      label:
                          '${profile.completed.length} de ${profile.catalogIds.length} níveis concluídos',
                      child: _HomeCard(
                        key: const ValueKey('home-progress'),
                        onTap: enabled && !profile.campaignComplete
                            ? onPlay
                            : null,
                        icon: Icons.bar_chart_rounded,
                        title: 'Seu progresso',
                        subtitle: 'Nível ${profile.currentLevelId}',
                        progress: true,
                        progressValue:
                            profile.completed.length /
                            profile.catalogIds.length,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (profile.campaignComplete) ...[
                      Text(
                        'Campanha concluída!',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const Text(
                        'Você descobriu todas as palavras desta coleção. Novos níveis chegarão em breve.',
                        textAlign: TextAlign.center,
                      ),
                    ] else
                      VolumeButton(
                        key: const ValueKey('play'),
                        onPressed: enabled ? onPlay : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.play_arrow_rounded, size: 36),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 25,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Tooltip(
                      message:
                          'Ganhe 50 moedas ao concluir. O desafio muda à meia-noite do aparelho e o progresso incompleto expira.',
                      child: _HomeCard(
                        key: const ValueKey('daily-play'),
                        onTap:
                            enabled &&
                                !coordinator.clockReversed &&
                                !dailyComplete
                            ? onDaily
                            : null,
                        icon: Icons.calendar_month_rounded,
                        title: 'Desafio diário',
                        subtitle: dailySubtitle,
                        caption: dailyComplete
                            ? 'Você já recebeu 50 moedas hoje.'
                            : null,
                        trailing: dailyComplete
                            ? Icons.check_circle_outline_rounded
                            : coordinator.clockReversed
                            ? Icons.lock_outline_rounded
                            : Icons.chevron_right_rounded,
                        coral: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _HomeCard(
                      key: const ValueKey('home-themes'),
                      onTap: controller.busy
                          ? null
                          : () => openThemes(context, controller),
                      icon: Icons.palette_rounded,
                      title: 'Temas',
                      subtitle: 'Atual: ${VisualThemeScope.of(context).title}',
                    ),
                    SaveStatus(controller: controller),
                    ThemeSaveFeedback(preferences: controller.preferences),
                  ],
                );
                final navigation = Row(
                  children: [
                    SettingsButton(controller: controller),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: WalletBadge(
                          balance: profile.balance,
                          onPressed: () => openShop(context, controller),
                        ),
                      ),
                    ),
                  ],
                );
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 22),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: wide ? 1040 : 460,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (wide) ...[
                                navigation,
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(child: hero),
                                    const SizedBox(width: 32),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 24),
                                        child: cards,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                HomeSky(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      navigation,
                                      const SizedBox(height: 4),
                                      hero,
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 38),
                                cards,
                              ],
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.coral = false,
    this.progress = false,
    this.progressValue = 0,
    this.caption,
    this.trailing = Icons.chevron_right_rounded,
  });
  final IconData icon;
  final IconData trailing;
  final String? caption;
  final String title, subtitle;
  final VoidCallback? onTap;
  final bool coral, progress;
  final double progressValue;
  @override
  Widget build(BuildContext context) => GardenCard(
    padding: EdgeInsets.zero,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: VisualThemeScope.of(context).isLagoon
                      ? null
                      : coral
                      ? const Color(0xFFFFE9D3)
                      : const Color(0xFFF3EAD6),
                  gradient: VisualThemeScope.of(context).isLagoon
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: coral
                              ? [const Color(0xFFFF9371), GameTheme.coral]
                              : progress
                              ? [
                                  const Color(0xFFFFD475),
                                  const Color(0xFFF3AA30),
                                ]
                              : [const Color(0xFF388B8C), GameTheme.teal],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(
                    VisualThemeScope.of(context).isLagoon ? 25 : 13,
                  ),
                ),
                child: Icon(
                  progress && VisualThemeScope.of(context).isLagoon
                      ? Icons.star_rounded
                      : icon,
                  size: 36,
                  color: VisualThemeScope.of(context).isLagoon
                      ? Colors.white
                      : coral
                      ? GameTheme.coral
                      : GameTheme.teal,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: progress ? 17 : 18,
                        fontWeight: progress
                            ? FontWeight.w700
                            : FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize:
                            progress && !VisualThemeScope.of(context).isLagoon
                            ? 23
                            : 14,
                        fontWeight: progress
                            ? FontWeight.w900
                            : FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                    if (progress) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progressValue,
                          minHeight: 5,
                          backgroundColor: const Color(0xFFF2DFC0),
                          color: GameTheme.teal,
                          semanticsLabel: 'Progresso na campanha',
                        ),
                      ),
                    ],
                    if (caption != null)
                      Text(caption!, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(trailing, size: 24, color: GameTheme.teal),
            ],
          ),
        ),
      ),
    ),
  );
}
