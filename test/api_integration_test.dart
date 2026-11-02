import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:caca_palavra/core/api/api_client.dart';
import 'package:caca_palavra/core/api/auth_session.dart';
import 'package:caca_palavra/core/api/google_link.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/application/theme_unlocks.dart';
import 'package:caca_palavra/features/game/data/api_progress_repository.dart';
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/data/progress_repository.dart';
import 'package:caca_palavra/features/game/data/daily_catalog.dart';
import 'package:caca_palavra/features/game/presentation/game_controller.dart';
import 'package:caca_palavra/features/game/presentation/game_screen.dart';
import 'package:caca_palavra/features/game/presentation/home_screen.dart';
import 'package:caca_palavra/features/game/presentation/settings_screen.dart';
import 'helpers.dart';

class MemoryCredentials implements CredentialStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

class FixedGoogle implements GoogleIdentityProvider {
  @override
  Future<String> idToken() async => 'same-google-proof';
}

/// Models the published API contracts and injects response loss after effects.
class Backend {
  Backend(this.data);
  final GameData data;
  String user = '00000000-0000-4000-8000-000000000001';
  String date = '2026-10-30';
  String name = 'Jogador teste';
  int coins = 300,
      last = 0,
      anonymous = 0,
      refreshes = 0,
      hints = 0,
      completions = 0,
      themeCharges = 0;
  bool lostHint = false,
      lostCompletion = false,
      failReads = false,
      dailyDone = false;
  final purchased = <String>{};
  final receipts = <String, Map<String, dynamic>>{};
  final requests = <http.Request>[];
  Map<String, dynamic> tokens() => {
    'idUsuario': user,
    'tokenType': 'Bearer',
    'accessToken': 'access-$refreshes-$user',
    'refreshToken': 'refresh-$refreshes-$user',
    'expiresIn': 900,
  };
  Map<String, dynamic> daily() => {
    'data': date,
    'idDesafio': DailyCatalog.fixture(data).forDate(date).id,
    'versaoCatalogo': data.catalogVersion,
    'expiraEm':
        '${DateTime.parse(date).add(const Duration(days: 1)).toIso8601String().substring(0, 10)}T03:00:00Z',
    'concluido': dailyDone,
  };
  Map<String, dynamic> state() => {
    'idUsuario': user,
    'idJogo': ApiConfig.gameId,
    'nomeUsuario': name,
    'progresso': {
      'ultimoNivelConcluido': last,
      'proximoNivel': last >= data.levels.length ? null : last + 1,
      'totalNiveis': data.levels.length,
      'campanhaConcluida': last >= data.levels.length,
      'versaoCatalogo': data.catalogVersion,
    },
    'moedas': {'qtdMoedas': coins},
    'beneficios': {'semAnuncios': false},
    'diario': daily(),
  };
  Map<String, dynamic> themeCatalog({bool onlyOwned = false}) => {
    'idUsuario': user,
    'temas': [
      for (final entry in ThemeUnlocks.rules.entries)
        if (!onlyOwned ||
            entry.value.price == null &&
                (entry.value.level == null || last + 1 >= entry.value.level!) ||
            purchased.contains(entry.key))
          {
            'idTema': entry.key,
            'nome': entry.key,
            'regraDesbloqueio': entry.value.price != null
                ? 'MOEDAS'
                : entry.value.level != null
                ? 'NIVEL'
                : 'GRATUITO',
            'precoMoedas': entry.value.price,
            'nivelNecessario': entry.value.level,
            'desbloqueado':
                purchased.contains(entry.key) ||
                entry.value.price == null &&
                    (entry.value.level == null ||
                        last + 1 >= entry.value.level!),
            'origemDesbloqueio': purchased.contains(entry.key)
                ? 'COMPRA'
                : null,
          },
    ],
  };
  http.Response json(Object value, {int status = 200}) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
  );
  http.Response error(String code, {int status = 409}) =>
      json({'code': code, 'correlationId': 'trace-test'}, status: status);
  Future<http.Response> handle(http.Request r) async {
    requests.add(r);
    final p = r.url.path;
    final body = r.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(r.body) as Map<String, dynamic>;
    if (p == '/api/v1/auth/anonymous') {
      expect(body['idJogo'], ApiConfig.gameId);
      anonymous++;
      expect(r.headers.containsKey('Authorization'), false);
      return json(tokens(), status: 201);
    }
    if (p == '/api/v1/auth/refresh') {
      expect(body['idJogo'], ApiConfig.gameId);
      refreshes++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(r.headers.containsKey('Authorization'), false);
      return json(tokens());
    }
    if (p == '/api/v1/auth/me/nome') {
      name = body['nomeUsuario'] as String;
    }
    if (p.startsWith('/api/v1/auth/me')) {
      return json({
        'idUsuario': user,
        'idJogo': ApiConfig.gameId,
        'nomeUsuario': name,
        'emailVinculado': null,
      });
    }
    if (p == '/api/v1/game/me' && failReads) {
      throw http.ClientException('lost read');
    }
    if (p == '/api/v1/game/me' || p == '/api/v1/game/inicializar') {
      expect(r.body, isEmpty);
      expect(r.url.hasQuery, false);
      return json(state());
    }
    if (p == '/api/v1/temas') return json(themeCatalog());
    if (p == '/api/v1/temas/me') return json(themeCatalog(onlyOwned: true));
    if (p == '/api/v1/diario') return json(daily());
    if (p.endsWith('/dicas')) {
      expect(body.keys.toSet(), {'tipoDica', 'versaoCatalogo'});
      final price = switch (body['tipoDica']) {
        'LETRA' => 50,
        'MASCOTE' => 70,
        'SUPER' => 120,
        _ => 999,
      };
      if (coins < price) return error('INSUFFICIENT_COINS');
      coins -= price;
      hints++;
      if (lostHint) {
        lostHint = false;
        throw http.ClientException('response lost after debit');
      }
      return json({
        'idMovimento': 'hint-$hints',
        'saldoAposOperacao': coins,
        'precoMoedas': price,
      });
    }
    if (p.endsWith('/conclusao')) {
      final key = '$user:$p';
      if (receipts[key] != null) {
        return json({...receipts[key]!, 'repetida': true});
      }
      final isDaily = p.startsWith('/api/v1/diario/');
      if (isDaily && !p.contains('/$date/')) return error('DIARIO_EXPIRADO');
      expect(
        body.keys.toSet(),
        isDaily ? {'versaoCatalogo'} : {'versaoCatalogo', 'explorador'},
      );
      completions++;
      final reward = isDaily ? 50 : 20 + (body['explorador'] == true ? 10 : 0);
      coins += reward;
      if (isDaily) {
        dailyDone = true;
      } else {
        last++;
      }
      final receipt = {
        'idMovimento': 'completion-$completions',
        'saldoAposOperacao': coins,
        'repetida': false,
      };
      receipts[key] = receipt;
      if (lostCompletion) {
        lostCompletion = false;
        throw http.ClientException('response lost after completion');
      }
      return json(receipt);
    }
    if (p.endsWith('/compra')) {
      expect(r.body, isEmpty);
      final id = r.url.pathSegments[r.url.pathSegments.length - 2];
      if (!purchased.contains(id)) {
        coins -= ThemeUnlocks.rule(id).price!;
        purchased.add(id);
        themeCharges++;
      }
      return json({
        'idMovimento': 'theme-$id',
        'saldoAposOperacao': coins,
        'repetida': themeCharges > 1,
      });
    }
    if (p == '/api/v1/moedas/movimentos') {
      return json({
        'pagina': int.parse(r.url.queryParameters['pagina']!),
        'tamanho': 20,
        'temProxima': false,
        'movimentos': [],
      });
    }
    return error('UNEXPECTED_ENDPOINT', status: 404);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late GameData data;
  late Backend backend;
  late MemoryCredentials store;
  late AuthSession auth;
  late ApiClient api;
  late Database db;
  late ApiProgressRepository repo;
  late GameSessionCoordinator game;
  var clock = DateTime.utc(2026, 10, 30, 12);
  Future<void> openGame() async {
    repo = ApiProgressRepository(db, auth);
    game = await GameSessionCoordinator.create(
      data,
      repo,
      dailyCatalog: DailyCatalog.fixture(data),
      random: Random(7),
    );
  }

  Future<void> word(String value) => game
      .submitWord(
        idsFor(game.engine, value),
        session: game.engine.state.session,
      )
      .then((_) {});
  Future<void> finish() async {
    for (final target in game.engine.state.level.words) {
      if (!game.engine.state.targets.contains(target.key)) {
        await word(target.key);
      }
    }
  }

  setUp(() async {
    data = loadData();
    backend = Backend(data);
    store = MemoryCredentials();
    clock = DateTime.utc(2026, 10, 30, 12);
    api = ApiClient(
      ApiConfig(
        authUrl: Uri.parse('http://auth.test'),
        gameUrl: Uri.parse('http://game.test'),
      ),
      client: MockClient(backend.handle),
    );
    auth = AuthSession(api, store, now: () => clock);
    await auth.restore();
    await auth.ensure();
    db = await LocalGameDatabase.open(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    await openGame();
  });
  tearDown(() async {
    await db.close();
    api.close();
  });

  test(
    'anonymous is persisted and concurrent expired requests share one refresh',
    () async {
      clock = clock.add(const Duration(minutes: 16));
      await Future.wait(
        List.generate(
          8,
          (_) => auth.authorized('GET', '/api/v1/auth/me', authService: true),
        ),
      );
      expect(backend.refreshes, 1);
      expect(backend.anonymous, 1);
      final reopened = AuthSession(api, store, now: () => clock);
      await reopened.restore();
      await reopened.ensure();
      expect(reopened.userId, auth.userId);
      expect(backend.anonymous, 1);
    },
  );

  test(
    'game identity is a fixed UUID and responses with numeric game IDs are rejected',
    () async {
      expect(
        ApiConfig.gameId,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(api.config.namespace, endsWith('|${ApiConfig.gameId}'));
      final legacyApi = ApiClient(
        api.config,
        client: MockClient((r) async {
          if (r.url.path == '/api/v1/game/inicializar') {
            return backend.json({...backend.state(), 'idJogo': 1});
          }
          return backend.handle(r);
        }),
      );
      final legacyAuth = AuthSession(legacyApi, store, now: () => clock);
      await legacyAuth.restore();
      await expectLater(
        ApiProgressRepository(db, legacyAuth).initialize(data),
        throwsA(
          isA<ApiFailure>().having((e) => e.code, 'code', 'INVALID_RESPONSE'),
        ),
      );
      legacyApi.close();
    },
  );

  test(
    'refresh response loss is durable and is never replayed after restart',
    () async {
      var calls = 0;
      final losing = ApiClient(
        api.config,
        client: MockClient((r) async {
          if (r.url.path.endsWith('/refresh')) {
            calls++;
            throw http.ClientException('lost');
          }
          return backend.handle(r);
        }),
      );
      final session = AuthSession(losing, store, now: () => clock);
      await session.restore();
      await expectLater(session.refresh(), throwsA(isA<ApiFailure>()));
      final reopened = AuthSession(losing, store);
      await reopened.restore();
      await expectLater(
        reopened.ensure(),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.code,
            'code',
            'SESSION_RECOVERY_REQUIRED',
          ),
        ),
      );
      expect(calls, 1);
      losing.close();
    },
  );

  test(
    'server progress hydrates without snapshots or a local financial ledger',
    () async {
      backend.last = 5;
      backend.coins = 77;
      await openGame();
      expect(game.profile.currentLevelId, 6);
      expect(game.profile.balance, 77);
      expect(game.profile.completed, {1, 2, 3, 4, 5});
      expect(game.profile.rounds, isEmpty);
      expect(await db.query('coin_transactions'), isEmpty);
      await game.startOrContinue();
      expect(game.engine.state.level.id, 6);
    },
  );

  test(
    'hints debit remotely, persist the reveal and local replay does not charge again',
    () async {
      await game.startOrContinue();
      final first = await game.purchaseHint(operationId: 'hint-1');
      expect(first.status, 'purchased');
      expect(game.profile.balance, 250);
      expect(backend.hints, 1);
      await game.purchaseHint(operationId: 'hint-1');
      expect(backend.hints, 1);
      await openGame();
      expect(game.activeRound!.paidHints, 1);
    },
  );

  test(
    'lost hint response is not replayed, including restart and user retry',
    () async {
      await game.startOrContinue();
      backend.lostHint = true;
      await expectLater(
        game.purchaseHint(operationId: 'lost'),
        throwsA(
          isA<ApiFailure>().having((e) => e.code, 'code', 'HINT_UNCERTAIN'),
        ),
      );
      expect(backend.hints, 1);
      expect(game.activeRound!.paidHints, 0);
      expect(repo.uncertainHint, true);
      await openGame();
      expect(repo.uncertainHint, true);
      await game.retry();
      expect(repo.uncertainHint, false);
      expect(backend.hints, 1);
      expect(game.profile.balance, 250);
    },
  );

  test(
    'a known hint receipt survives a later failure without another debit',
    () async {
      await game.startOrContinue();
      backend.failReads = true;
      await expectLater(
        game.purchaseHint(operationId: 'known'),
        throwsA(isA<ApiFailure>()),
      );
      expect(backend.hints, 1);
      backend.failReads = false;
      await game.retry();
      expect(backend.hints, 1);
      expect(game.activeRound!.paidHints, 1);
    },
  );

  test(
    'explorer is paid only with completion and lost completion response is replayable',
    () async {
      await game.startOrContinue();
      await word('TOGA');
      expect(game.engine.state.explorerUnlocked, true);
      expect(game.profile.balance, 300);
      backend.lostCompletion = true;
      await expectLater(finish(), throwsA(isA<ApiFailure>()));
      expect(backend.completions, 1);
      expect(game.profile.completed, isEmpty);
      await game.retry();
      expect(backend.completions, 1);
      expect(game.profile.balance, 330);
      expect(game.profile.explorerRewardedLevels, {1});
      expect(game.profile.pendingCompletion, isNotNull);
      await game.advance();
      expect(game.profile.currentLevelId, 2);
    },
  );

  test(
    'theme purchase uses no body and server ownership, with no local welcome credit',
    () async {
      backend.coins = 900;
      await game.refreshDaily();
      await game.purchaseTheme('capivara_lagoa');
      await game.purchaseTheme('capivara_lagoa');
      expect(backend.themeCharges, 1);
      expect(game.profile.balance, 400);
      expect(game.isThemeUnlocked('capivara_lagoa'), true);
      expect(await db.query('profiles'), isEmpty);
    },
  );

  test(
    'server date and completion are used instead of the device calendar',
    () async {
      backend.date = '2026-01-01';
      await game.refreshDaily();
      expect(game.today, '2026-01-01');
      await game.startDaily();
      expect(game.activeDay!.definition.id, 1);
      await finish();
      expect(backend.dailyDone, true);
      expect(backend.last, 0);
      expect(game.profile.balance, 350);
      await game.advance();
      expect(game.dailyCompleted, true);
    },
  );

  test(
    'switched identity cannot run previous account pending operations',
    () async {
      await game.startOrContinue();
      backend.failReads = true;
      await expectLater(
        game.purchaseHint(operationId: 'old-account'),
        throwsA(isA<ApiFailure>()),
      );
      backend.failReads = false;
      backend.user = '00000000-0000-4000-8000-000000000002';
      await auth.accept(backend.tokens());
      await expectLater(game.retry(), throwsA(isA<ApiFailure>()));
      expect(backend.hints, 1);
      await openGame();
      expect(game.profile.rounds, isEmpty);
      expect(await repo.pending(), isEmpty);
    },
  );

  test(
    'mascot and super hints use the corresponding API type and saved mascot text is free',
    () async {
      await game.startOrContinue();
      await game.purchaseMascotHint('GATO', operationId: 'mascot-1');
      await game.purchaseMascotHint('GATO', operationId: 'mascot-reread');
      expect(backend.hints, 1);
      await game.purchaseSuperHint(operationId: 'super-1');
      await game.purchaseHint(operationId: 'letter-1');
      expect(backend.hints, 3);
      expect(game.profile.balance, 60);
      expect(
        backend.requests
            .where((r) => r.url.path.endsWith('/dicas'))
            .map((r) => (jsonDecode(r.body) as Map)['tipoDica']),
        ['MASCOTE', 'SUPER', 'LETRA'],
      );
    },
  );

  test(
    'hint that completes a phase does not buy again when completion response is lost',
    () async {
      await game.startOrContinue();
      await word('GATO');
      await word('GOTA');
      await game.purchaseHint(operationId: 'letter-one');
      await game.purchaseHint(operationId: 'letter-two');
      backend.lostCompletion = true;
      await expectLater(
        game.purchaseHint(operationId: 'letter-three'),
        throwsA(isA<ApiFailure>()),
      );
      expect(backend.hints, 3);
      expect(backend.completions, 1);
      await game.retry();
      expect(backend.hints, 3);
      expect(backend.completions, 1);
      expect(game.activeRound!.paidHints, 3);
      expect(game.profile.balance, 170);
    },
  );

  test('shop credits are unavailable in the online coordinator', () async {
    await expectLater(
      game.simulatePurchase('coins_500'),
      throwsA(isA<ApiFailure>()),
    );
    await expectLater(game.watchRewardAd(), throwsA(isA<ApiFailure>()));
    expect(game.profile.balance, 300);
  });

  test(
    'reconnection reads both services and preserves a partial round and identity',
    () async {
      await game.startOrContinue();
      await word(game.engine.state.level.words.first.key);
      final controller = GameController(game.engine, coordinator: game);
      addTearDown(controller.dispose);
      final round = game.activeRound!.roundId;
      final targets = Set<String>.of(game.engine.state.targets);
      final user = auth.userId;
      backend.failReads = true;
      await controller.refreshCalendar();
      expect(controller.lastApiFailure?.connectionFailure, true);
      controller.setConnectionBlocked(true);
      backend.failReads = false;
      backend.requests.clear();
      await controller.reconnect();
      controller.setConnectionBlocked(false);
      expect(controller.saveError, isNull);
      expect(controller.interactive, true);
      expect(game.activeRound!.roundId, round);
      expect(game.engine.state.targets, targets);
      expect(auth.userId, user);
      expect(backend.requests.every((r) => r.method == 'GET'), true);
      expect(
        backend.requests.any((r) => r.url.path == '/api/v1/auth/me'),
        true,
      );
      expect(
        backend.requests.any((r) => r.url.path == '/api/v1/game/me'),
        true,
      );
    },
  );

  test(
    'reconnection does not replay an uncertain completion or purchase',
    () async {
      await game.startOrContinue();
      backend.lostCompletion = true;
      await expectLater(finish(), throwsA(isA<ApiFailure>()));
      final controller = GameController(game.engine, coordinator: game);
      addTearDown(controller.dispose);
      controller.lastApiFailure = const ApiFailure('NETWORK_ERROR');
      controller.saveError = controller.lastApiFailure!.message;
      backend.requests.clear();
      await controller.reconnect();
      expect(game.hasFailedCommand, true);
      expect(backend.completions, 1);
      expect(backend.requests.every((r) => r.method == 'GET'), true);
      expect(controller.saveError, contains('salvamento pendente'));
      await controller.retrySave();
      expect(game.hasFailedCommand, false);
      expect(backend.completions, 1);
    },
  );

  testWidgets(
    'online game hides plan action and insufficient coins offer no shop',
    (tester) async {
      await tester.runAsync(() async {
        backend.coins = 0;
        await game.refreshDaily();
        await game.startOrContinue();
      });
      final controller = GameController(game.engine, coordinator: game);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(controller: controller)),
      );
      expect(find.byKey(const ValueKey('ad-free')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Abrir loja')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('hint')));
      await tester.pumpAndSettle();
      expect(find.text('Ir à loja'), findsNothing);
      expect(find.text('Moedas insuficientes'), findsOneWidget);
      await tester.tap(find.text('Agora não'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'settings edit the account name within 30 characters without coin history',
    (tester) async {
      final controller = GameController(game.engine, coordinator: game);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(controller: controller, onPlay: () {}),
        ),
      );
      expect(find.bySemanticsLabel(RegExp('Abrir loja')), findsNothing);
      expect(
        find.text('Olá, Jogador teste!', findRichText: true),
        findsOneWidget,
      );
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(controller: controller)),
      );
      expect(find.text('Minha conta'), findsOneWidget);
      expect(find.text('Conectar com Google'), findsOneWidget);
      expect(find.text('Recuperar conta Google'), findsNothing);
      expect(find.text('Histórico de moedas'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('edit-player-name')));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('player-name-field'));
      await tester.enterText(field, ' ');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.text('Use um nome de 2 a 30 caracteres.'), findsOneWidget);
      expect(backend.name, 'Jogador teste');
      final maxName = List.filled(30, 'A').join();
      await tester.enterText(field, '${maxName}B');
      expect(tester.widget<TextFormField>(field).controller!.text, maxName);
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(backend.name, maxName);
      expect(find.text(maxName), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.text(maxName));
      await tester.pumpAndSettle();
      await tester.enterText(field, 'Não salvar');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(backend.name, maxName);
      expect(backend.requests.where((r) => r.method == 'PATCH').length, 1);
      expect(
        backend.requests.any((r) => r.url.path == '/api/v1/moedas/movimentos'),
        false,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(controller: controller, onPlay: () {}),
        ),
      );
      expect(find.text('Olá, $maxName!', findRichText: true), findsOneWidget);
    },
  );

  test(
    'Google resume omits bearer, retains same proof and atomically installs selected credentials',
    () async {
      var confirmed = false;
      var resumeCount = 0;
      final googleApi = ApiClient(
        api.config,
        client: MockClient((r) async {
          final body = jsonDecode(r.body) as Map;
          if (r.url.path.endsWith('/consultar')) {
            return backend.json({
              'codigoOperacao': 'code',
              'expiraEm': '2026-10-30T13:00:00Z',
              'escolhaNecessaria': false,
              'jaVinculado': false,
              'usuarioAtual': {},
              'usuarioExistente': null,
            });
          }
          expect(body['googleIdToken'], 'same-google-proof');
          if (r.url.path.endsWith('/confirmar')) {
            confirmed = true;
            throw http.ClientException('response lost after migration');
          }
          if (r.url.path.endsWith('/retomar')) {
            expect(confirmed, true);
            expect(r.headers.containsKey('Authorization'), false);
            resumeCount++;
            return backend.json({
              ...backend.tokens(),
              'idUsuario': 'google-user',
            });
          }
          return backend.handle(r);
        }),
      );
      final session = AuthSession(googleApi, store, now: () => clock);
      await session.restore();
      final link = GoogleLink(session, FixedGoogle());
      await link.consult();
      await expectLater(link.confirm('ANONIMO'), throwsA(isA<ApiFailure>()));
      final restarted = AuthSession(googleApi, store, now: () => clock);
      await restarted.restore();
      await GoogleLink(restarted, FixedGoogle()).resume();
      expect(restarted.userId, 'google-user');
      expect(restarted.googleOperation, isNull);
      expect(resumeCount, 1);
      googleApi.close();
    },
  );
}
