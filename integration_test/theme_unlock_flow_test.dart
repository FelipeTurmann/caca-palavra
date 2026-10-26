import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:caca_palavra/app.dart';
import 'package:caca_palavra/core/feedback/game_feedback.dart';
import 'package:caca_palavra/core/preferences/player_preferences.dart';
import 'package:caca_palavra/core/theme/visual_theme_catalog.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/data/progress_repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android: locked themes, legacy fallback, permanent purchase and restart',
    (tester) async {
      final location = path.join(
        await getDatabasesPath(),
        'theme_unlock_integration.db',
      );
      // Only this dedicated fixture is reset; the normal player's data is preserved.
      await deleteDatabase(location);
      final data = await GameData.load();
      var repo = await SqliteProgressRepository.open(
        databasePath: location,
        initialBalance: 1200,
      );
      var session = await GameSessionCoordinator.create(data, repo);
      final store = SqlitePreferencesStore(repo.database);
      await store.write(
        const PlayerPreferences(
          visualThemeId: 'capivara_lagoa',
          introduction: Introduction.exempted,
        ),
      );
      Future<void> mount() async {
        await tester.pumpWidget(
          WordGameApp(
            loader: () async => session,
            feedbackOutput: SilentFeedbackOutput(),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await mount();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      expect(find.text('Atual: Jardim do Gatinho'), findsOneWidget);
      expect((await store.read()).visualTheme, VisualTheme.garden);
      await tap(find.byKey(const ValueKey('home-themes')));
      expect(find.text('Libera no nível 50'), findsOneWidget);
      expect(find.text('Libera no nível 100'), findsOneWidget);
      await binding.takeScreenshot('01-cadeados-precos');
      await tester.ensureVisible(
        find.byKey(const ValueKey('unlock-theme-escola_magia')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('unlock-theme-escola_magia')),
            )
            .onPressed,
        isNull,
      );
      await binding.takeScreenshot('02-cadeados-niveis');
      expect(session.profile.balance, 1200);
      await tap(find.byKey(const ValueKey('unlock-theme-capivara_lagoa')));
      await binding.takeScreenshot('03-confirmacao-compra');
      await tap(find.text('Cancelar'));
      expect(session.profile.balance, 1200);
      await tap(find.byKey(const ValueKey('unlock-theme-capivara_lagoa')));
      await tap(find.byKey(const ValueKey('confirm-unlock-capivara_lagoa')));
      expect(session.profile.balance, 700);
      expect(
        find.byKey(const ValueKey('theme-lock-capivara_lagoa')),
        findsNothing,
      );
      await binding.takeScreenshot('04-tema-desbloqueado');
      await tap(
        find.byKey(const ValueKey('unlock-theme-biblioteca_encantada')),
      );
      expect(find.textContaining('Faltam 50 moedas'), findsOneWidget);
      await binding.takeScreenshot('05-saldo-insuficiente');
      await tap(find.text('Entendi'));
      await tap(find.byKey(const ValueKey('use-theme-jardim_gatinho')));
      await tap(find.byKey(const ValueKey('use-theme-capivara_lagoa')));
      expect(session.profile.balance, 700);
      final ledger = await repo.database.query('coin_transactions');
      expect(
        ledger.where((row) => row['kind'] == 'theme_unlock'),
        hasLength(1),
      );
      await tap(find.byTooltip('Fechar temas'));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      repo = await SqliteProgressRepository.open(databasePath: location);
      session = await GameSessionCoordinator.create(data, repo);
      await mount();
      expect(find.text('Atual: Capivara na lagoa'), findsOneWidget);
      expect(session.profile.balance, 700);
      expect(await repo.database.query('coin_transactions'), ledger);
      await binding.takeScreenshot('06-reabertura');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
