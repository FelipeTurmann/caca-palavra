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
    if (controller.coordinator?.online?.uncertainHint == true) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Uma dica pode ter sido cobrada sem que sua resposta fosse recebida. Confira o saldo antes de continuar.',
            textAlign: TextAlign.center,
          ),
          TextButton(
            onPressed: controller.busy ? null : controller.retrySave,
            child: const Text('Atualizar saldo e continuar'),
          ),
        ],
      );
    }
    if (controller.saveError != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            controller.saveError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          if (controller.coordinator?.online?.session.needsRecovery == true &&
              controller.onSessionChanged != null)
            FilledButton(
              onPressed: controller.busy
                  ? null
                  : () async {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                      await controller.onSessionChanged!();
                    },
              child: const Text('Recuperar acesso'),
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
          coordinator.dailyCompleted ||
          (day?.completed == true && day?.pendingResult == false);
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
                // Keep the normal phone home within the safe viewport. Large
                // accessibility text and recovery notices retain natural flow.
                final fitHome =
                    !wide &&
                    constraints.maxHeight >= 480 &&
                    constraints.maxHeight > constraints.maxWidth &&
                    scale <= 1.3 &&
                    !profile.campaignComplete &&
                    !coordinator.clockReversed &&
                    controller.saveError == null &&
                    coordinator.online?.uncertainHint != true &&
                    controller.preferences.error == null;
                final compact = fitHome && constraints.maxHeight < 740;
                final gap = compact ? 8.0 : 14.0;
                final actionLabel = compact && profile.hasStarted
                    ? (profile.pendingCompletion != null
                          ? 'Ver resultado'
                          : 'Continuar')
                    : label;
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
                final greeting = coordinator.online == null
                    ? null
                    : Padding(
                        padding: EdgeInsets.only(
                          top: compact ? 2 : 6,
                          bottom: compact ? 6 : 12,
                        ),
                        child: Text.rich(
                          TextSpan(
                            text: 'Olá, ',
                            children: [
                              TextSpan(
                                text: coordinator.online!.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const TextSpan(text: '!'),
                            ],
                          ),
                          key: const ValueKey('home-greeting'),
                          textAlign: TextAlign.center,
                          softWrap: true,
                          maxLines: fitHome ? 2 : null,
                          overflow: fitHome ? TextOverflow.ellipsis : null,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.3,
                            fontWeight: FontWeight.w400,
                            color: GameTheme.ink,
                          ),
                        ),
                      );
                final hero = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ?greeting,
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
                        compact: compact,
                        trailing: null,
                        icon: Icons.bar_chart_rounded,
                        title: 'Seu progresso',
                        subtitle: 'Nível ${profile.currentLevelId}',
                        progress: true,
                        progressValue:
                            profile.completed.length /
                            profile.catalogIds.length,
                      ),
                    ),
                    SizedBox(height: gap),
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
                          padding: EdgeInsets.symmetric(
                            vertical: compact ? 0 : 3,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                size: compact ? 30 : 36,
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  actionLabel,
                                  semanticsLabel: label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: Theme.of(
                                      context,
                                    ).textTheme.titleLarge?.fontFamily,
                                    fontSize: compact ? 22 : 25,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    SizedBox(height: gap),
                    Tooltip(
                      message:
                          'Ganhe 50 moedas ao concluir. O desafio muda à meia-noite do aparelho e o progresso incompleto expira.',
                      child: _HomeCard(
                        key: const ValueKey('daily-play'),
                        compact: compact,
                        onTap:
                            enabled &&
                                !coordinator.clockReversed &&
                                !dailyComplete
                            ? onDaily
                            : null,
                        icon: Icons.calendar_month_rounded,
                        title: 'Desafio diário',
                        subtitle: dailySubtitle,
                        caption: dailyComplete && !compact
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
                    SizedBox(height: gap),
                    _HomeCard(
                      key: const ValueKey('home-themes'),
                      compact: compact,
                      onTap: controller.busy
                          ? null
                          : () => openThemes(context, controller),
                      icon: Icons.palette_rounded,
                      title: 'Temas',
                      subtitle: 'Atual: ${VisualThemeScope.of(context).title}',
                    ),
                    if (!fitHome) ...[
                      SaveStatus(controller: controller),
                      ThemeSaveFeedback(preferences: controller.preferences),
                    ],
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
                          onPressed: controller.shopAvailable
                              ? () => openShop(context, controller)
                              : null,
                        ),
                      ),
                    ),
                  ],
                );
                if (fitHome) {
                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 14 : 20,
                          6,
                          compact ? 14 : 20,
                          12,
                        ),
                        child: Column(
                          key: const ValueKey('home-fitted-layout'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            navigation,
                            SizedBox(
                              height: 4,
                              child:
                                  controller.busy ||
                                      controller.preferences.savingTheme
                                  ? const LinearProgressIndicator(
                                      semanticsLabel: 'Salvando progresso',
                                    )
                                  : null,
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  ?greeting,
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, space) {
                                        if (space.maxHeight < 48) {
                                          return const SizedBox.shrink();
                                        }
                                        final withArt = space.maxHeight >= 180;
                                        return Column(
                                          children: [
                                            Expanded(
                                              flex: withArt ? 2 : 1,
                                              child: Center(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: SizedBox(
                                                    width: width,
                                                    child: brand,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (withArt)
                                              Expanded(
                                                flex: 3,
                                                child: LayoutBuilder(
                                                  builder: (context, art) =>
                                                      Center(
                                                        child: HomeWordGarden(
                                                          height: math.min(
                                                            art.maxHeight,
                                                            artHeight,
                                                          ),
                                                          fullBleed: true,
                                                        ),
                                                      ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: compact ? 8 : 16),
                            cards,
                          ],
                        ),
                      ),
                    ),
                  );
                }
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
    this.compact = false,
  });
  final IconData icon;
  final IconData? trailing;
  final String? caption;
  final String title, subtitle;
  final VoidCallback? onTap;
  final bool coral, progress;
  final bool compact;
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
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 14,
            vertical: compact ? 8 : 12,
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 40 : 50,
                height: compact ? 40 : 50,
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
                  size: compact ? 28 : 36,
                  color: VisualThemeScope.of(context).isLagoon
                      ? Colors.white
                      : coral
                      ? GameTheme.coral
                      : GameTheme.teal,
                ),
              ),
              SizedBox(width: compact ? 10 : 14),
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
                            ? (compact ? 20 : 23)
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
              if (trailing != null) ...[
                const SizedBox(width: 6),
                Icon(trailing, size: 24, color: GameTheme.teal),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
