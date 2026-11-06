import 'dart:async';
import 'dart:convert';

import 'package:caca_palavra/app.dart';
import 'package:caca_palavra/core/api/api_client.dart';
import 'package:caca_palavra/core/api/auth_session.dart';
import 'package:caca_palavra/core/api/connection_monitor.dart';
import 'package:caca_palavra/core/feedback/game_feedback.dart';
import 'package:caca_palavra/core/preferences/player_preferences.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/presentation/game_screen.dart';
import 'package:caca_palavra/features/game/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'api_integration_test.dart' show MemoryCredentials;
import 'campaign_widget_test.dart' show MemoryProgressRepository;
import 'helpers.dart';

class ManualNetworkAccess implements NetworkAccessSource {
  ManualNetworkAccess(this.available);
  bool? available;
  int checks = 0;
  final events = StreamController<bool?>.broadcast(sync: true);
  @override
  Future<bool?> check() async {
    checks++;
    return available;
  }

  @override
  Stream<bool?> get changes => events.stream;
  void change(bool? value) {
    available = value;
    events.add(value);
  }
}

class HookedCredentials extends MemoryCredentials {
  void Function(Map<String, dynamic>)? afterWrite;
  @override
  Future<void> write(String value) async {
    await super.write(value);
    afterWrite?.call(jsonDecode(value) as Map<String, dynamic>);
  }
}

void main() {
  for (final afterSend in [false, true]) {
    test(
      'refresh interrupted ${afterSend ? 'after' : 'before'} send retains the correct recovery state',
      () async {
        final source = ManualNetworkAccess(true);
        final connection = ConnectionMonitor(source);
        final store = HookedCredentials();
        var requests = 0;
        final api = ApiClient(
          ApiConfig(
            authUrl: Uri.parse('http://auth.test'),
            gameUrl: Uri.parse('http://game.test'),
          ),
          connection: connection,
          client: MockClient((request) async {
            requests++;
            if (afterSend && request.url.path.endsWith('/refresh')) {
              source.change(false);
              throw http.ClientException('response lost after sending');
            }
            return http.Response(
              jsonEncode({
                'idUsuario': 'same-user',
                'tokenType': 'Bearer',
                'accessToken': 'access-$requests',
                'refreshToken': 'refresh-$requests',
                'expiresIn': 900,
              }),
              200,
            );
          }),
        );
        addTearDown(() async {
          connection.dispose();
          await source.events.close();
          api.close();
        });
        final auth = AuthSession(api, store);
        await auth.restore();
        await auth.ensure();
        if (!afterSend) {
          store.afterWrite = (value) {
            if (value['refreshPending'] == true) source.change(false);
          };
        }
        await expectLater(auth.refresh(), throwsA(isA<ApiFailure>()));
        expect(auth.needsRecovery, afterSend);
        expect(requests, afterSend ? 2 : 1);
        expect(auth.userId, 'same-user');
        store.afterWrite = null;
        source.change(true);
        await connection.retry(() async => true);
        await auth.restore();
        if (afterSend) {
          await expectLater(
            auth.ensure(),
            throwsA(
              isA<ApiFailure>().having(
                (e) => e.code,
                'code',
                'SESSION_RECOVERY_REQUIRED',
              ),
            ),
          );
          expect(requests, 2);
        } else {
          await auth.refresh();
          expect(auth.needsRecovery, false);
          expect(requests, 2);
        }
      },
    );
  }
  test(
    'offline blocks identity creation and refresh without invalidating credentials',
    () async {
      final source = ManualNetworkAccess(false);
      final connection = ConnectionMonitor(source);
      final store = MemoryCredentials();
      var now = DateTime.utc(2026, 11, 2);
      var requests = 0;
      final api = ApiClient(
        ApiConfig(
          authUrl: Uri.parse('http://auth.test'),
          gameUrl: Uri.parse('http://game.test'),
        ),
        connection: connection,
        client: MockClient((request) async {
          requests++;
          return http.Response(
            jsonEncode({
              'idUsuario': 'same-user',
              'tokenType': 'Bearer',
              'accessToken': 'access-$requests',
              'refreshToken': 'refresh-$requests',
              'expiresIn': 900,
            }),
            200,
          );
        }),
      );
      addTearDown(() async {
        connection.dispose();
        await source.events.close();
        api.close();
      });
      final auth = AuthSession(api, store, now: () => now);
      await auth.restore();
      await expectLater(
        auth.ensure(),
        throwsA(
          isA<ApiFailure>().having((e) => e.requestNotSent, 'not sent', true),
        ),
      );
      expect(requests, 0);
      source.change(true);
      await connection.retry(() async => true);
      await auth.ensure();
      final credentials = store.value;
      now = now.add(const Duration(minutes: 20));
      source.change(false);
      await expectLater(auth.ensure(), throwsA(isA<ApiFailure>()));
      await expectLater(auth.refresh(), throwsA(isA<ApiFailure>()));
      expect(store.value, credentials);
      expect(auth.needsRecovery, false);
      expect(requests, 1);
      source.change(true);
      await connection.retry(() async => true);
      await auth.ensure();
      expect(requests, 2);
      expect(auth.userId, 'same-user');
    },
  );

  test(
    'server failures on a validated network are not classified as offline',
    () async {
      final source = ManualNetworkAccess(true);
      final connection = ConnectionMonitor(source);
      var status = 503;
      var transportFailure = false;
      final api = ApiClient(
        ApiConfig(
          authUrl: Uri.parse('http://auth.test'),
          gameUrl: Uri.parse('http://game.test'),
        ),
        connection: connection,
        client: MockClient((_) async {
          if (transportFailure) throw http.ClientException('refused');
          return http.Response('{}', status);
        }),
      );
      addTearDown(() async {
        connection.dispose();
        await source.events.close();
        api.close();
      });
      await expectLater(
        api.request('GET', '/state'),
        throwsA(isA<ApiFailure>()),
      );
      expect(connection.problem, ConnectionProblem.serviceUnavailable);
      await connection.retry(() async {
        try {
          await api.request('GET', '/state');
          return true;
        } on ApiFailure {
          return false;
        }
      });
      expect(connection.blocked, true);
      status = 200;
      await connection.retry(() async {
        await api.request('GET', '/state');
        return true;
      });
      expect(connection.blocked, false);
      transportFailure = true;
      await expectLater(
        api.request('GET', '/state'),
        throwsA(isA<ApiFailure>()),
      );
      expect(connection.problem, ConnectionProblem.serviceUnavailable);
    },
  );

  test(
    'reconnection verifies once and cannot unlock with a result from before a network drop',
    () async {
      final source = ManualNetworkAccess(false);
      final connection = ConnectionMonitor(source);
      addTearDown(() async {
        connection.dispose();
        await source.events.close();
      });
      await connection.start();
      source.change(true);
      expect(connection.blocked, true);
      final pending = Completer<bool>();
      var probes = 0;
      final retry = connection.retry(() {
        probes++;
        return pending.future;
      });
      await Future<void>.delayed(Duration.zero);
      await connection.retry(() async {
        probes++;
        return true;
      });
      expect(probes, 1);
      source.change(false);
      source.change(true);
      pending.complete(true);
      await retry;
      expect(connection.problem, ConnectionProblem.serviceUnavailable);
      expect(connection.checking, false);
      await connection.retry(() async => true);
      expect(connection.blocked, false);
    },
  );

  testWidgets(
    'manual startup retry and automatic recovery preserve the active round',
    (tester) async {
      final source = ManualNetworkAccess(false);
      final connection = ConnectionMonitor(source);
      var loads = 0;
      final game = await GameSessionCoordinator.create(
        loadData(),
        MemoryProgressRepository(60),
      );
      await tester.pumpWidget(
        WordGameApp(
          connection: connection,
          preferencesStore: MemoryPreferencesStore(),
          feedbackOutput: SilentFeedbackOutput(),
          loader: () async {
            loads++;
            return game;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sem conexão com a internet'), findsWidgets);
      expect(loads, 0);
      source.available = true;
      await tester.tap(find.byKey(const ValueKey('retry-connection')).last);
      await tester.pumpAndSettle();
      expect(loads, 1);
      final controller = tester
          .widget<HomeScreen>(find.byType(HomeScreen))
          .controller;
      await tester.tap(find.byKey(const ValueKey('play')));
      await tester.pumpAndSettle();
      expect(find.byType(GameScreen), findsOneWidget);
      final round = game.activeRound!.roundId;
      final balance = game.profile.balance;
      source.change(false);
      await tester.pumpAndSettle();
      expect(controller.interactive, false);
      expect(find.text('Sem conexão com a internet'), findsOneWidget);
      await controller.run(() async {
        fail('A blocked action must not execute');
      });
      source.change(true);
      await tester.pumpAndSettle();
      expect(controller.interactive, true);
      expect(game.activeRound!.roundId, round);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      source.change(false);
      source.available = true;
      final checks = source.checks;
      await tester.pump(const Duration(seconds: 10));
      expect(source.checks, checks);
      expect(controller.interactive, false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(controller.interactive, true);
      expect(source.checks, checks + 1);
      expect(game.activeRound!.roundId, round);
      expect(game.profile.balance, balance);
      expect(loads, 1);
      await tester.pumpWidget(const SizedBox());
      connection.dispose();
      await source.events.close();
    },
  );

  testWidgets('service outage retries at increasing intervals until recovery', (
    tester,
  ) async {
    final source = ManualNetworkAccess(true);
    final connection = ConnectionMonitor(source);
    final game = await GameSessionCoordinator.create(
      loadData(),
      MemoryProgressRepository(60),
    );
    var loads = 0;
    await tester.pumpWidget(
      WordGameApp(
        connection: connection,
        feedbackOutput: SilentFeedbackOutput(),
        loader: () async {
          if (++loads < 3) throw const ApiFailure('NETWORK_ERROR');
          return game;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(loads, 1);
    expect(connection.problem, ConnectionProblem.serviceUnavailable);
    await tester.pump(const Duration(seconds: 1));
    expect(loads, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(loads, 2);
    expect(connection.blocked, true);
    await tester.pump(const Duration(seconds: 3));
    expect(loads, 2);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(loads, 3);
    expect(connection.blocked, false);
    expect(find.text('Jogar'), findsOneWidget);
    final checks = source.checks;
    await tester.pump(const Duration(seconds: 30));
    expect(source.checks, checks);
    await tester.pumpWidget(const SizedBox());
    connection.dispose();
    await source.events.close();
  });
}
