import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:caca_palavra/core/api/api_client.dart';
import 'package:caca_palavra/core/api/auth_session.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/data/api_progress_repository.dart';
import 'package:caca_palavra/features/game/data/daily_catalog.dart';
import 'package:caca_palavra/features/game/data/progress_repository.dart';
import 'helpers.dart';

class _EphemeralCredentials implements CredentialStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'local auth + game APIs accept the Flutter session and gameplay contracts',
    () async {
      // Opt-in only: creates a fresh test identity and game records in local dev.
      // No real purchases, Google sign-in, existing accounts or secrets on disk.
      final previousOverride = HttpOverrides.current;
      HttpOverrides.global = null;
      final api = ApiClient(
        ApiConfig(
          authUrl: Uri.parse('http://127.0.0.1:8081'),
          gameUrl: Uri.parse('http://127.0.0.1:8082'),
        ),
      );
      final auth = AuthSession(api, _EphemeralCredentials());
      sqfliteFfiInit();
      final db = await LocalGameDatabase.open(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      try {
        await auth.restore();
        await auth.ensure();
        final originalUser = auth.userId;
        await auth.refresh();
        expect(auth.userId, originalUser);
        final playerName = 'Teste API ${originalUser.substring(0, 8)}';
        await auth.authorized(
          'PATCH',
          '/api/v1/auth/me/nome',
          authService: true,
          body: {'nomeUsuario': playerName},
        );
        final other = AuthSession(api, _EphemeralCredentials());
        await other.restore();
        await other.ensure();
        final beforeRename = await other.authorized(
          'GET',
          '/api/v1/auth/me',
          authService: true,
        );
        await expectLater(
          other.authorized(
            'PATCH',
            '/api/v1/auth/me/nome',
            authService: true,
            body: {'nomeUsuario': ' ${playerName.toLowerCase()} '},
          ),
          throwsA(
            isA<ApiFailure>()
                .having((error) => error.status, 'status', 409)
                .having((error) => error.code, 'code', 'PLAYER_NAME_TAKEN'),
          ),
        );
        final afterRename = await other.authorized(
          'GET',
          '/api/v1/auth/me',
          authService: true,
        );
        expect(afterRename['nomeUsuario'], beforeRename['nomeUsuario']);
        final data = loadProductionData();
        final repo = ApiProgressRepository(db, auth);
        final game = await GameSessionCoordinator.create(
          data,
          repo,
          dailyCatalog: await DailyCatalog.load(),
        );
        expect(game.profile.balance, 60);
        expect(game.profile.currentLevelId, 1);
        expect(repo.name, playerName);
        expect(game.shopAvailable, false);
        await game.startOrContinue();
        await game.purchaseHint(operationId: 'live-letter-hint');
        expect(game.profile.balance, 10);
        Future<void> finish() async {
          for (final target in game.engine.state.level.words) {
            if (!game.engine.state.targets.contains(target.key)) {
              await game.submitWord(
                idsFor(game.engine, target.key),
                session: game.engine.state.session,
              );
            }
          }
        }

        for (var level = 1; level <= 25; level++) {
          await finish();
          expect(game.profile.completed.contains(level), true);
          await game.advance();
        }
        expect(game.profile.balance, 510);
        await game.purchaseTheme('capivara_lagoa');
        await game.purchaseTheme('capivara_lagoa');
        expect(game.profile.balance, 10);
        expect(game.isThemeUnlocked('capivara_lagoa'), true);
        await game.startDaily();
        await finish();
        expect(game.profile.balance, 60);
        await game.advance();
        expect(game.dailyCompleted, true);
        final history = await auth.authorized(
          'GET',
          '/api/v1/moedas/movimentos',
          query: {'pagina': '0', 'tamanho': '100'},
        );
        expect((history['movimentos'] as List).length, 29);
        expect(game.profile.completed.length, 25);
      } finally {
        await db.close();
        api.close();
        HttpOverrides.global = previousOverride;
      }
    },
    skip: !const bool.fromEnvironment('LIVE_API_CHECK'),
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
