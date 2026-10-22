import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../domain/game_engine.dart';
import '../application/game_session_coordinator.dart';
import '../application/daily_models.dart';
import 'wheel_gesture.dart';

abstract final class GameTiming {
  static const feedback = Duration(milliseconds: 1200);
  static const completion = Duration(milliseconds: 350);
  static const shuffle = Duration(milliseconds: 200);
  static const pulse = Duration(milliseconds: 300);
  static const extraCollect = Duration(milliseconds: 800);
  static const explorerCelebration = Duration(milliseconds: 1800);
}

class ExtraDiscovery {
  const ExtraDiscovery({
    required this.id,
    required this.session,
    required this.word,
    required this.explorerUnlocked,
  });
  final int id;
  final int session;
  final WordEntry word;
  final bool explorerUnlocked;
}

class GameController extends ChangeNotifier {
  GameController(this._fixtureEngine, {this.coordinator, this.onHome});
  final GameSessionCoordinator? coordinator;
  final VoidCallback? onHome;
  bool busy = false;
  String? saveError;
  LetterReveal? paidReveal;
  int get balance => coordinator?.profile.balance ?? 0;
  bool get explorerRewardGranted =>
      !isDaily &&
      (coordinator?.profile.explorerRewardedLevels.contains(state.level.id) ??
          false);
  bool shopOpen = false;
  String? creditMessage;
  Timer? _calendarTimer;
  bool get isDaily => coordinator?.mode == GameMode.daily;
  bool get dailyInvalid => coordinator?.dailyInvalid ?? false;
  int get completionReward => coordinator?.completionReward ?? 20;
  Future<void> waitIdle() async {
    await _active;
  }

  void scheduleCalendarCheck() {
    _calendarTimer?.cancel();
    final time = coordinator!.now();
    final midnight = DateTime(time.year, time.month, time.day + 1);
    var delay = midnight.difference(time);
    if (delay > const Duration(minutes: 1)) delay = const Duration(minutes: 1);
    if (delay <= Duration.zero) delay = const Duration(milliseconds: 1);
    _calendarTimer = Timer(delay, () async {
      await refreshCalendar();
      if (!_disposed) scheduleCalendarCheck();
    });
  }

  Future<void> refreshCalendar() async {
    await waitIdle();
    if (_disposed || coordinator == null) return;
    try {
      await coordinator!.refreshDaily();
      if (dailyInvalid) {
        cancelGesture(notify: false);
        clearCollectionEffects(notify: false);
        feedback = null;
      }
    } catch (_) {
      saveError =
          'Não foi possível atualizar o desafio diário. Tente novamente.';
    }
    refresh();
  }

  Future<SuperHintOutcome?> buySuperHint(String id, RoundContext? expected) =>
      run(() async {
        final result = await coordinator!.purchaseSuperHint(
          operationId: id,
          expected: expected,
        );
        if (result.submission != null) _accept(result.submission!);
        return result;
      });
  Future<Map<String, dynamic>?> credit(
    Future<Map<String, dynamic>> Function() command,
  ) async {
    final result = await run(() async {
      final saved = await command();
      _showCredit(saved);
      return saved;
    });
    if (result == null && saveError != null) {
      saveError = 'Não foi possível adicionar as moedas. Tente novamente.';
      refresh();
    }
    return result;
  }

  void _showCredit(Map<String, dynamic> result) {
    creditMessage = result['source'] == 'simulated_purchase'
        ? 'Compra simulada: +${result['amount']} moedas. Nenhuma cobrança realizada.'
        : '+${result['amount']} moedas adicionadas pela simulação.';
  }

  bool get lastLevel => state.level.id == engine.levels.last.id;
  Future<void>? _active;
  Future<T?> run<T>(Future<T> Function() action) async {
    if (busy) return null;
    busy = true;
    saveError = null;
    refresh();
    final done = Completer<void>();
    _active = done.future;
    try {
      return await action();
    } on DailyExpired {
      cancelGesture(notify: false);
      clearCollectionEffects(notify: false);
      feedback = null;
      return null;
    } on ClockReversed {
      return null;
    } catch (_) {
      saveError = 'Não foi possível salvar seu progresso. Tente novamente.';
      return null;
    } finally {
      busy = false;
      done.complete();
      _active = null;
      refresh();
    }
  }

  Future<void> retrySave() async {
    await run(() async {
      final result = await coordinator!.retry();
      if (result?['kind'] == 'submission' || result?['kind'] == 'super_hint') {
        _accept(submissionFromJson(result!));
      }
      if (result?['kind'] == 'hint') {
        paidReveal = revealFromJson(result!['reveal']);
        feedbackSerial++;
      }
      if (result?['kind'] == 'shop') _showCredit(result!);
      if (result?['kind'] == 'advance') _clearRound();
      if (result?['home'] == true) onHome?.call();
    });
  }

  Future<HintOutcome?> buyHint(String id, {RoundContext? expected}) =>
      run(() async {
        final result = await coordinator!.purchaseHint(
          operationId: id,
          expected: expected,
        );
        paidReveal = result.reveal;
        feedbackSerial++;
        return result;
      });
  Future<void> leaveToHome() async {
    if (dragging) {
      cancelGesture();
      return;
    }
    await _active;
    if (saveError != null) return;
    detach();
    onHome?.call();
  }

  final GameEngine _fixtureEngine;
  GameEngine get engine => coordinator?.engine ?? _fixtureEngine;
  final WheelGesture gesture = WheelGesture();
  WheelGeometry? _geometry;
  Timer? _feedbackTimer;
  Timer? _completionTimer;
  Timer? _shuffleTimer;
  Timer? _explorerTimer;
  final List<ExtraDiscovery> _discoveries = [];
  int _discoverySerial = 0;
  int collectedSerial = 0;
  bool celebratingExplorer = false;
  List<ExtraDiscovery> get discoveries => List.unmodifiable(_discoveries);
  bool _disposed = false;
  bool shuffling = false;
  SubmissionResult? feedback;
  int feedbackSerial = 0;
  GameState get state => engine.state;
  bool get dragging => gesture.dragging;
  bool get interactive =>
      state.phase == RoundPhase.playing &&
      !shuffling &&
      !dailyInvalid &&
      !shopOpen &&
      !busy &&
      saveError == null;
  String get preview {
    final tiles = {for (final tile in state.level.tiles) tile.id: tile.letter};
    return gesture.selected.map((id) => tiles[id] ?? '').join();
  }

  /// Called during layout; the wheel schedules a repaint after cancellation.
  bool configureGeometry(WheelGeometry geometry) {
    final changed = _geometry != null && !_geometry!.sameAs(geometry);
    _geometry = geometry;
    return changed && gesture.cancel();
  }

  void refresh() {
    if (!_disposed) notifyListeners();
  }

  void down(int pointer, Offset position) {
    if (!interactive || _geometry == null) return;
    if (gesture.down(pointer, position, _geometry!)) {
      _explorerTimer?.cancel();
      celebratingExplorer = false;
      _feedbackTimer?.cancel();
      feedback = null;
      paidReveal = null;
      notifyListeners();
    }
  }

  void move(int pointer, Offset position) {
    if (_geometry != null && gesture.move(pointer, position, _geometry!)) {
      notifyListeners();
    }
  }

  void up(int pointer, Offset position) {
    if (gesture.pointer != pointer) return;
    move(pointer, position);
    final ids = gesture.up(pointer);
    if (ids == null) return;
    if (coordinator != null) {
      final session = state.session;
      unawaited(
        run(() async {
          _accept(await coordinator!.submitWord(ids, session: session));
        }),
      );
      return;
    }
    _accept(engine.submit(ids, session: state.session));
  }

  void _accept(SubmissionResult result) {
    if (_disposed) return;
    if (result.kind == SubmissionKind.extraFound) {
      _discoveries.add(
        ExtraDiscovery(
          id: ++_discoverySerial,
          session: state.session,
          word: result.word!,
          explorerUnlocked: result.explorerUnlocked,
        ),
      );
    }
    feedback = result.kind == SubmissionKind.ignored ? null : result;
    feedbackSerial++;
    _feedbackTimer?.cancel();
    if (feedback != null) {
      _feedbackTimer = Timer(GameTiming.feedback, () {
        feedback = null;
        refresh();
      });
    }
    if (result.completed) {
      final session = state.session;
      _completionTimer?.cancel();
      _completionTimer = Timer(GameTiming.completion, () {
        if (engine.finishCompletion(session)) {
          clearCollectionEffects(notify: false);
          refresh();
        }
      });
    }
    notifyListeners();
  }

  void cancelPointer(int pointer) {
    if (gesture.pointer == pointer) cancelGesture();
  }

  void finishDiscovery(ExtraDiscovery discovery) {
    if (_disposed ||
        discovery.session != state.session ||
        !_discoveries.remove(discovery)) {
      return;
    }
    collectedSerial++;
    if (discovery.explorerUnlocked &&
        !dragging &&
        feedback?.kind == SubmissionKind.extraFound &&
        feedback?.word?.key == discovery.word.key) {
      celebratingExplorer = true;
      _explorerTimer?.cancel();
      _explorerTimer = Timer(GameTiming.explorerCelebration, () {
        celebratingExplorer = false;
        refresh();
      });
    }
    refresh();
  }

  void clearCollectionEffects({bool notify = true}) {
    _discoveries.clear();
    _explorerTimer?.cancel();
    celebratingExplorer = false;
    if (notify) refresh();
  }

  void cancelGesture({bool notify = true}) {
    if (gesture.cancel() && notify) refresh();
  }

  void shuffle({bool reduceMotion = false}) {
    if (!interactive || dragging) return;
    if (coordinator != null) {
      unawaited(
        run(() async {
          if (await coordinator!.shuffle()) _animateShuffle(reduceMotion);
        }),
      );
      return;
    }
    if (!engine.shuffle(dragging: dragging)) return;
    _animateShuffle(reduceMotion);
  }

  void _animateShuffle(bool reduceMotion) {
    if (_disposed) return;
    _geometry = null;
    shuffling = !reduceMotion;
    _shuffleTimer?.cancel();
    if (shuffling) {
      _shuffleTimer = Timer(GameTiming.shuffle, () {
        shuffling = false;
        refresh();
      });
    }
    notifyListeners();
  }

  void nextLevel() {
    if (state.phase != RoundPhase.completed) return;
    if (busy || saveError != null) return;
    if (coordinator != null) {
      unawaited(
        run(() async {
          final next = await coordinator!.advance();
          _clearRound();
          if (!next) onHome?.call();
        }),
      );
      return;
    }
    final index = engine.levels.indexWhere(
      (level) => level.id == state.level.id,
    );
    if (index + 1 == engine.levels.length) {
      onHome?.call();
      return;
    }
    engine.startLevel(engine.levels[index + 1].id);
    _clearRound();
    refresh();
  }

  void resetView() => _clearRound();
  void _clearRound() {
    if (_disposed) return;
    _cancelTimers();
    gesture.cancel();
    _geometry = null;
    feedback = null;
    shuffling = false;
    clearCollectionEffects(notify: false);
    collectedSerial = 0;
    paidReveal = null;
    notifyListeners();
  }

  void detach() {
    _cancelTimers();
    gesture.cancel();
    shuffling = false;
    clearCollectionEffects(notify: false);
  }

  void _cancelTimers() {
    _feedbackTimer?.cancel();
    _completionTimer?.cancel();
    _shuffleTimer?.cancel();
    _explorerTimer?.cancel();
  }

  @override
  void dispose() {
    _disposed = true;
    _calendarTimer?.cancel();
    _cancelTimers();
    gesture.cancel();
    _discoveries.clear();
    super.dispose();
  }
}
