import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/application/theme_unlocks.dart';
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/data/progress_repository.dart';
import 'package:caca_palavra/features/game/domain/game_engine.dart';
import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory folder;
  late String location;
  late SqliteProgressRepository repo;
  late GameSessionCoordinator session;
  final data = loadData();
  Future<void> open({int balance = 4000, GameData? catalog}) async {
    repo = await SqliteProgressRepository.open(
      factory: databaseFactoryFfi,
      databasePath: location,
      initialBalance: balance,
    );
    session = await GameSessionCoordinator.create(catalog ?? data, repo);
  }

  Future<void> fresh(int balance) async {
    await session.close();
    await databaseFactoryFfi.deleteDatabase(location);
    await open(balance: balance);
  }

  Future<void> reopen() async {
    await session.close();
    await open();
  }

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('theme-unlocks-');
    location = '${folder.path}/game.db';
    await open();
  });
  tearDown(() async {
    await session.close();
    if (folder.absolute.path.startsWith(Directory.systemTemp.absolute.path)) {
      await folder.delete(recursive: true);
    }
  });

  test('rules match the seven themes and milestone boundaries', () {
    expect(ThemeUnlocks.rules.length, 7);
    for (final entry in {
      'capivara_lagoa': 500,
      'biblioteca_encantada': 750,
      'fundo_mar': 1000,
      'jardim_abelhas': 1200,
    }.entries) {
      expect(ThemeUnlocks.rule(entry.key).price, entry.value);
      expect(session.isThemeUnlocked(entry.key), false);
    }
    expect(session.isThemeUnlocked('jardim_gatinho'), true);
    for (final (id, level) in [('escola_magia', 50), ('refugio_neve', 100)]) {
      expect(ThemeUnlocks.available(id, {}, {level - 1}), false);
      expect(ThemeUnlocks.available(id, {}, {level}), true);
      expect(ThemeUnlocks.available(id, {}, {level + 1}), true);
    }
  });
  test(
    'each exact balance buys once, persists and never changes the round',
    () async {
      for (final entry in ThemeUnlocks.rules.entries.where(
        (e) => e.value.price != null,
      )) {
        await fresh(entry.value.price!);
        await session.startOrContinue();
        final round = session.activeRound!.toJson();
        final id = entry.key;
        expect((await session.purchaseTheme(id))['status'], 'purchased');
        expect(session.profile.balance, 0);
        expect(session.activeRound!.toJson(), round);
        await session.purchaseTheme(id);
        expect(session.profile.balance, 0);
        await reopen();
        expect(session.isThemeUnlocked(id), true);
        expect(session.profile.balance, 0);
        expect(
          await repo.database.query(
            'coin_transactions',
            where: 'kind = ?',
            whereArgs: ['theme_unlock'],
          ),
          hasLength(1),
        );
      }
    },
  );
  test('one coin short never creates a debit or pending unlock', () async {
    for (final entry in ThemeUnlocks.rules.entries.where(
      (e) => e.value.price != null,
    )) {
      await fresh(entry.value.price! - 1);
      final before = session.profile.toPayload();
      expect(
        (await session.purchaseTheme(entry.key))['status'],
        'insufficient',
      );
      expect(session.profile.toPayload(), before);
      expect(await repo.pending(), isEmpty);
      expect(await repo.database.query('coin_transactions'), hasLength(1));
    }
  });
  test(
    'concurrent purchases of one theme debit once; other themes remain independent',
    () async {
      await Future.wait(
        List.generate(5, (_) => session.purchaseTheme('capivara_lagoa')),
      );
      await session.purchaseTheme('biblioteca_encantada');
      expect(session.profile.balance, 2750);
      expect(session.profile.purchasedThemes, {
        'capivara_lagoa',
        'biblioteca_encantada',
      });
      expect(session.isThemeUnlocked('fundo_mar'), false);
      expect(await repo.database.query('coin_transactions'), hasLength(3));
    },
  );
  test('campaign and daily share the same permanent purchase', () async {
    await session.startDaily();
    final round = session.activeRound!.toJson();
    await session.purchaseTheme('fundo_mar');
    expect(session.activeRound!.toJson(), round);
    await session.startOrContinue();
    expect(session.isThemeUnlocked('fundo_mar'), true);
    expect(session.profile.balance, 3000);
  });
  test('free and milestone themes cannot be bought with coins', () async {
    final before = session.profile.toPayload();
    expect((await session.purchaseTheme('escola_magia'))['status'], 'locked');
    expect((await session.purchaseTheme('refugio_neve'))['status'], 'locked');
    expect(
      (await session.purchaseTheme('jardim_gatinho'))['status'],
      'available',
    );
    await expectLater(session.purchaseTheme('unknown'), throwsArgumentError);
    expect(session.profile.balance, 4000);
    expect(session.profile.toPayload(), before);
  });
  for (final fault in [
    StorageFaultPoint.afterLedger,
    StorageFaultPoint.beforeCommit,
  ]) {
    test(
      'rollback and prepared recovery at $fault preserve single debit',
      () async {
        repo.fault = (point) {
          if (point == fault) throw StateError('disk');
        };
        await expectLater(
          session.purchaseTheme('jardim_abelhas'),
          throwsStateError,
        );
        expect(session.profile.balance, 4000);
        expect(await repo.database.query('coin_transactions'), hasLength(1));
        await reopen();
        expect(session.isThemeUnlocked('jardim_abelhas'), true);
        expect(session.profile.balance, 2800);
        await session.purchaseTheme('jardim_abelhas');
        expect(await repo.database.query('coin_transactions'), hasLength(2));
      },
    );
  }
  test('lost commit acknowledgement resolves to the original unlock', () async {
    repo.fault = (point) {
      if (point == StorageFaultPoint.afterCommit) throw StateError('ack');
    };
    await session.purchaseTheme('capivara_lagoa');
    expect(session.profile.balance, 3500);
    await reopen();
    expect(session.isThemeUnlocked('capivara_lagoa'), true);
    expect(await repo.pending(), isEmpty);
  });
  test(
    'an unlock injected without its ledger is rejected without resetting data',
    () async {
      final row = (await repo.database.query('profiles')).single;
      final payload =
          jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
      payload['purchasedThemes'] = ['capivara_lagoa'];
      await repo.database.update('profiles', {
        'payload_json': jsonEncode(payload),
      });
      await expectLater(repo.load(data), throwsFormatException);
      expect((await repo.database.query('profiles')).single['balance'], 4000);
    },
  );
  test(
    'milestones use saved campaign progression and survive reopening',
    () async {
      await session.close();
      await databaseFactoryFfi.deleteDatabase(location);
      final word = WordEntry('ATO');
      final futureCatalog = GameData(
        [
          for (final id in [1, 49, 50, 99, 100])
            LevelDefinition(
              id: id,
              difficulty: 'fixture',
              letters: const ['A', 'T', 'O'],
              words: [word],
            ),
        ],
        {'ATO': word},
      );
      await open(catalog: futureCatalog);
      await session.startOrContinue();
      for (final id in [1, 49, 50, 99]) {
        await session.submitWord(
          idsFor(session.engine, 'ATO'),
          session: session.engine.state.session,
        );
        expect(session.isThemeUnlocked('escola_magia'), id >= 49);
        expect(session.isThemeUnlocked('refugio_neve'), id >= 99);
        await session.advance();
      }
      final balance = session.profile.balance;
      await session.close();
      await open(catalog: futureCatalog);
      expect(session.isThemeUnlocked('escola_magia'), true);
      expect(session.isThemeUnlocked('refugio_neve'), true);
      expect(session.profile.balance, balance);
      expect(session.profile.purchasedThemes, isEmpty);
    },
  );
}
