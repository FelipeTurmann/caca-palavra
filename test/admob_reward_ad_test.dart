import 'dart:async';
import 'dart:io';

import 'package:caca_palavra/core/monetization/admob_reward_ad_provider.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/application/shop_models.dart';
import 'package:caca_palavra/features/game/data/progress_repository.dart';
import 'package:caca_palavra/features/game/presentation/game_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';

class ControlledRewardAd implements LoadedRewardAd {
  final shown = Completer<void>();
  late VoidCallback earn, dismiss, fail;
  bool disposed = false;

  @override
  Future<void> show({
    required VoidCallback onEarned,
    required VoidCallback onDismissed,
    required VoidCallback onFailed,
  }) async {
    earn = onEarned;
    dismiss = onDismissed;
    fail = onFailed;
    shown.complete();
  }

  @override
  void dispose() => disposed = true;
}

class ControlledGateway implements RewardAdGateway {
  ControlledRewardAd ad = ControlledRewardAd();
  int loads = 0;
  bool unavailable = false;

  @override
  Future<LoadedRewardAd> load() async {
    loads++;
    if (unavailable) throw const RewardAdException('Anúncio indisponível.');
    return ad;
  }
}

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late SqliteProgressRepository repository;
  late GameSessionCoordinator session;
  late ControlledGateway gateway;
  late AdMobTestRewardAdProvider provider;

  Future<void> reopen() async {
    repository = await SqliteProgressRepository.open(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/ads.db',
    );
    session = await GameSessionCoordinator.create(
      loadData(),
      repository,
      adProvider: provider,
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('admob_test_');
    gateway = ControlledGateway();
    provider = AdMobTestRewardAdProvider(gateway: gateway);
    await reopen();
  });

  tearDown(() async {
    await session.close();
    await directory.delete(recursive: true);
  });

  test(
    'SDK reward credits exactly once and survives reopening and replay',
    () async {
      // Legacy simulated receipts must remain readable beside SDK demo receipts.
      await session.simulatePurchase('coins_500', id: 'old-purchase');
      final first = session.watchRewardAd(id: 'sdk-order');
      final duplicate = session.watchRewardAd(id: 'sdk-order');
      await gateway.ad.shown.future;
      expect(session.profile.balance, 560);
      gateway.ad.earn();
      gateway.ad.earn();
      gateway.ad.dismiss();
      final results = await Future.wait([first, duplicate]);
      expect(session.profile.balance, 575);
      expect(gateway.loads, 1);
      expect(gateway.ad.disposed, isTrue);
      expect(results.first['simulated'], isFalse);
      expect(results.first['testAd'], isTrue);
      await session.close();
      await reopen();
      await session.watchRewardAd(id: 'sdk-order');
      expect(session.profile.balance, 575);
      expect(gateway.loads, 1);
      expect(
        await repository.database.query(
          'coin_transactions',
          where: 'kind = ?',
          whereArgs: ['admob_test'],
        ),
        hasLength(1),
      );
    },
  );

  test(
    'dismissal without earned callback creates no credit or save error',
    () async {
      final controller = GameController(session.engine, coordinator: session);
      addTearDown(controller.dispose);
      final watching = controller.credit(
        () => session.watchRewardAd(id: 'closed'),
      );
      await gateway.ad.shown.future;
      gateway.ad.dismiss();
      await watching;
      // Late/duplicate callbacks cannot turn a cancelled view into a reward.
      gateway.ad.earn();
      expect(session.profile.balance, 60);
      expect(await repository.resolveOperation('closed'), isNull);
      expect(controller.saveError, isNull);
      expect(controller.busy, isFalse);
      expect(controller.creditMessage, contains('sem recompensa'));
      expect(gateway.ad.disposed, isTrue);
    },
  );

  test(
    'load failure leaves wallet unchanged and allows another attempt',
    () async {
      gateway.unavailable = true;
      await expectLater(
        session.watchRewardAd(id: 'load-failed'),
        throwsA(isA<RewardAdException>()),
      );
      expect(session.profile.balance, 60);
      gateway.unavailable = false;
      final watching = session.watchRewardAd(id: 'loaded');
      await gateway.ad.shown.future;
      gateway.ad.earn();
      gateway.ad.dismiss();
      await watching;
      expect(session.profile.balance, 75);
    },
  );

  test(
    'failure to display disposes the ad without issuing a receipt',
    () async {
      final watching = session.watchRewardAd(id: 'show-failed');
      final assertion = expectLater(
        watching,
        throwsA(isA<RewardAdException>()),
      );
      await gateway.ad.shown.future;
      gateway.ad.fail();
      await assertion;
      expect(session.profile.balance, 60);
      expect(gateway.ad.disposed, isTrue);
      expect(await repository.resolveOperation('show-failed'), isNull);
    },
  );

  test(
    'retry after a failed wallet commit does not show or reward twice',
    () async {
      repository.fault = (point) {
        if (point == StorageFaultPoint.afterLedger) {
          throw StateError('disk fault');
        }
      };
      final watching = session.watchRewardAd(id: 'retry-order');
      final assertion = expectLater(watching, throwsStateError);
      await gateway.ad.shown.future;
      gateway.ad.earn();
      gateway.ad.dismiss();
      await assertion;
      expect(session.profile.balance, 60);
      repository.fault = null;
      await session.retry();
      await session.watchRewardAd(id: 'retry-order');
      expect(session.profile.balance, 75);
      expect(gateway.loads, 1);
    },
  );
}
