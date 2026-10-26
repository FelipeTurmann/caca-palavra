import 'dart:async';
import 'core/monetization/ad_free_plan.dart';
import 'core/monetization/admob_reward_ad_provider.dart';
import 'core/preferences/player_preferences.dart';
import 'core/feedback/game_feedback.dart';
import 'core/theme/visual_theme_catalog.dart';
import 'core/widgets/motion_policy.dart';
import 'package:flutter/material.dart';
import 'core/theme/game_theme.dart';
import 'features/game/application/game_session_coordinator.dart';
import 'features/game/data/game_data.dart';
import 'features/game/data/daily_catalog.dart';
import 'features/game/data/progress_repository.dart';
import 'features/game/presentation/game_controller.dart';
import 'features/game/presentation/game_screen.dart';
import 'features/game/presentation/home_screen.dart';

Future<GameSessionCoordinator> loadGame() async {
  final data = await GameData.load();
  final repository = await SqliteProgressRepository.open();
  try {
    return await GameSessionCoordinator.create(
      data,
      repository,
      dailyCatalog: await DailyCatalog.load(),
      adProvider: AdMobTestRewardAdProvider(),
    );
  } catch (_) {
    await repository.close();
    rethrow;
  }
}

class WordGameApp extends StatefulWidget {
  const WordGameApp({
    super.key,
    this.loader,
    this.preferencesStore,
    this.feedbackOutput,
  });
  final PreferencesStore? preferencesStore;
  final FeedbackOutput? feedbackOutput;
  final Future<GameSessionCoordinator> Function()? loader;
  @override
  State<WordGameApp> createState() => _WordGameAppState();
}

class _WordGameAppState extends State<WordGameApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loaded?.effects.resume();
      _loaded?.refreshCalendar();
    } else {
      _loaded?.suspendPresentation();
    }
  }

  late Future<GameController> _loading = _load();
  GameController? _loaded;
  bool _playing = false;
  Future<GameController> _load() async {
    final session = await (widget.loader ?? loadGame)();
    final repository = session.repository;
    final store =
        widget.preferencesStore ??
        (repository is SqliteProgressRepository
            ? SqlitePreferencesStore(repository.database)
            : MemoryPreferencesStore());
    final preferences = await PreferencesController.load(store);
    if (!session.isThemeUnlocked(preferences.value.visualThemeId)) {
      await preferences.selectTheme(VisualTheme.garden);
    }
    final controller = GameController(
      session.engine,
      adFreePlan: await AdFreePlanController.load(
        repository is SqliteProgressRepository
            ? SqliteAdFreePlanStore(repository.database)
            : MemoryAdFreePlanStore(),
      ),
      preferences: preferences,
      feedbackOutput: widget.feedbackOutput ?? AndroidFeedbackOutput(),
      coordinator: session,
      onHome: () {
        if (mounted) setState(() => _playing = false);
      },
    );
    if (!mounted) {
      controller.dispose();
      await session.close();
    } else {
      setState(() => _loaded = controller);
      unawaited(controller.effects.prepare());
      controller.scheduleCalendarCheck();
    }
    return controller;
  }

  Future<void> _play(GameController controller) async {
    final opened = await controller.run(() async {
      await controller.coordinator!.startOrContinue();
      return true;
    });
    if (opened == true && mounted) setState(() => _playing = true);
  }

  Future<void> _daily(GameController controller) async {
    final opened = await controller.run(() async {
      await controller.coordinator!.startDaily();
      return true;
    });
    if (opened == true && mounted) setState(() => _playing = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loaded?.dispose();
    if (_loaded != null) {
      final controller = _loaded!;
      unawaited(
        Future.wait([
          controller.preferences.flush(),
          controller.adFreePlan.flush(),
        ]).then((_) => controller.coordinator!.close()),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Conecte palavras',
    theme: GameTheme.theme,
    builder: (context, child) {
      final preferences = _loaded?.preferences;
      if (preferences == null) return child!;
      return ListenableBuilder(
        listenable: preferences,
        builder: (context, _) {
          final media = MediaQuery.of(context);
          return VisualThemeScope(
            theme: preferences.value.visualTheme,
            child: MotionPolicy(
              systemReduced: media.disableAnimations,
              child: MediaQuery(
                data: media.copyWith(
                  disableAnimations:
                      media.disableAnimations || preferences.value.reduceMotion,
                ),
                child: child!,
              ),
            ),
          );
        },
      );
    },
    home: FutureBuilder<GameController>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Não foi possível carregar seu progresso.\nSeus dados foram preservados.',
                          textAlign: TextAlign.center,
                        ),
                        if (snapshot.error is FormatException)
                          Text(
                            (snapshot.error as FormatException).message,
                            textAlign: TextAlign.center,
                          ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => setState(() {
                            _loading = _load();
                          }),
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final controller = snapshot.requireData;
        return _playing
            ? GameScreen(controller: controller)
            : HomeScreen(
                controller: controller,
                onPlay: () => _play(controller),
                onDaily: () => _daily(controller),
              );
      },
    ),
  );
}
