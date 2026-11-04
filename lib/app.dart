import 'dart:async';
import 'core/monetization/ad_free_plan.dart';
import 'core/api/api_client.dart';
import 'core/api/auth_session.dart';
import 'core/api/google_link.dart';
import 'core/api/connection_monitor.dart';
import 'core/widgets/connection_gate.dart';
import 'core/widgets/game_loading.dart';
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
import 'features/game/data/api_progress_repository.dart';
import 'features/game/presentation/account_screen.dart';
import 'features/game/presentation/game_controller.dart';
import 'features/game/presentation/game_screen.dart';
import 'features/game/presentation/home_screen.dart';

AuthSession? _defaultSession;
final defaultConnection = ConnectionMonitor(AndroidNetworkAccessSource());
AuthSession get defaultSession {
  final config = ApiConfig.environmentConfig();
  return _defaultSession ??= AuthSession(
    ApiClient(config, connection: defaultConnection),
    SecureCredentialStore(config.namespace),
  );
}

Future<GameSessionCoordinator> loadGame() async {
  final auth = defaultSession;
  await auth.restore();
  if (auth.googleOperation?['started'] == true) {
    try {
      await GoogleLink(
        auth,
        GoogleSdkIdentityProvider(auth.api.config.googleClientId),
      ).resume();
    } on ApiFailure catch (e) {
      if (e.code != 'GOOGLE_OPERATION_EXPIRED') rethrow;
      await auth.clearGoogle();
    }
  }
  await auth.ensure();
  final data = await GameData.load();
  final repository = await ApiProgressRepository.openOnline(auth);
  try {
    return await GameSessionCoordinator.create(
      data,
      repository,
      dailyCatalog: await DailyCatalog.load(),
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
    this.connection,
  });
  final PreferencesStore? preferencesStore;
  final FeedbackOutput? feedbackOutput;
  final ConnectionMonitor? connection;
  final Future<GameSessionCoordinator> Function()? loader;
  @override
  State<WordGameApp> createState() => _WordGameAppState();
}

class _WordGameAppState extends State<WordGameApp> with WidgetsBindingObserver {
  late final ConnectionMonitor? _connection =
      widget.connection ?? (widget.loader == null ? defaultConnection : null);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connection?.addListener(_connectionChanged);
    if (_connection != null) unawaited(_connection.start());
  }

  void _connectionChanged() {
    if (mounted) _loaded?.setConnectionBlocked(_connection!.blocked);
  }

  Future<void> _retryConnection() async {
    final connection = _connection;
    if (connection == null) return;
    await connection.retry(() async {
      try {
        final controller = _loaded;
        if (controller == null) {
          setState(() => _loading = _load());
          await _loading;
        } else {
          await controller.reconnect();
        }
        return true;
      } on ApiFailure catch (error) {
        if (!error.connectionFailure) return true;
        connection.reportServiceFailure();
        return false;
      } catch (_) {
        // The startup view still presents non-network errors with their retry.
        return _loaded == null;
      }
    });
  }

  Future<void> _resumeConnection() async {
    await _connection?.refreshNetwork();
    if (!mounted || _connection?.blocked == true) return;
    _loaded?.effects.resume();
    await _loaded?.refreshCalendar();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_resumeConnection());
    } else {
      _loaded?.suspendPresentation();
    }
  }

  late Future<GameController> _loading = _load();
  GameController? _loaded;
  bool _playing = false;
  bool _recoverGoogle = false;
  bool _loadingAccount = false;

  Future<void> _reloadAccount() async {
    final previous = _loaded;
    if (mounted) {
      setState(() {
        _loaded = null;
        _playing = false;
        _loadingAccount = true;
        _loading = () async {
          await previous?.waitIdle();
          await previous?.preferences.flush();
          previous?.dispose();
          await previous?.coordinator?.close();
          return _load();
        }();
      });
    }
  }

  Future<GameController> _load() async {
    await _connection?.start();
    if (_connection?.internetAvailable == false) {
      throw const ApiFailure('OFFLINE', requestNotSent: true);
    }
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
        repository is ApiProgressRepository
            ? RemoteAdFreePlanStore(() => repository.adFree)
            : repository is SqliteProgressRepository
            ? SqliteAdFreePlanStore(repository.database)
            : MemoryAdFreePlanStore(),
      ),
      preferences: preferences,
      feedbackOutput: widget.feedbackOutput ?? AndroidFeedbackOutput(),
      coordinator: session,
      onSessionChanged: _reloadAccount,
      onHome: () {
        if (mounted) setState(() => _playing = false);
      },
    );
    if (!mounted) {
      controller.dispose();
      await session.close();
    } else {
      setState(() => _loaded = controller);
      controller.setConnectionBlocked(_connection?.blocked == true);
      unawaited(controller.effects.prepare());
      controller.scheduleCalendarCheck();
      if (_recoverGoogle) {
        _recoverGoogle = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) openAccount(context, controller, startGoogle: true);
        });
      }
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
    _connection?.removeListener(_connectionChanged);
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
      final content = _connection == null
          ? child!
          : ConnectionGate(
              connection: _connection,
              onRetry: () => unawaited(_retryConnection()),
              child: child!,
            );
      final preferences = _loaded?.preferences;
      if (preferences == null) return content;
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
                child: content,
              ),
            ),
          );
        },
      );
    },
    home: FutureBuilder<GameController>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return GameLoadingScreen(account: _loadingAccount);
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          if (error is ApiFailure && error.connectionFailure) {
            return Scaffold(
              body: ConnectionNotice(
                offline: error.code == 'OFFLINE',
                checking: false,
                onRetry: () => setState(() => _loading = _load()),
              ),
            );
          }
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
                        if (snapshot.error is ApiFailure)
                          Text(
                            (snapshot.error as ApiFailure).message,
                            textAlign: TextAlign.center,
                          ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => setState(() {
                            _loading = _load();
                          }),
                          child: const Text('Tentar novamente'),
                        ),
                        if (snapshot.error is ApiFailure &&
                            widget.loader == null &&
                            {
                              'SESSION_RECOVERY_REQUIRED',
                              'INVALID_REFRESH_TOKEN',
                              'USER_BLOCKED',
                              'INVALID_ACCESS_TOKEN',
                              'ACCESS_TOKEN_EXPIRED',
                            }.contains((snapshot.error as ApiFailure).code))
                          TextButton(
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (dialog) => AlertDialog(
                                  title: const Text('Recuperar conta Google'),
                                  content: const Text(
                                    'Vamos abrir uma conta temporária para localizar sua conta Google. Seu progresso anterior será preservado no aparelho. Na próxima tela, escolha a conta que deseja manter.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialog, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(dialog, true),
                                      child: const Text('Continuar'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok != true || !mounted) return;
                              setState(() {
                                _recoverGoogle = true;
                                _loadingAccount = true;
                                _loading = () async {
                                  await defaultSession.createRecoveryIdentity();
                                  return _load();
                                }();
                              });
                            },
                            child: const Text('Recuperar conta com Google'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
