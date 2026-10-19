import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../domain/game_engine.dart';
import 'wheel_gesture.dart';

abstract final class GameTiming {
  static const feedback = Duration(milliseconds: 1200);
  static const completion = Duration(milliseconds: 350);
  static const shuffle = Duration(milliseconds: 200);
  static const pulse = Duration(milliseconds: 300);
}

class GameController extends ChangeNotifier {
  GameController(this.engine);
  final GameEngine engine;
  final WheelGesture gesture = WheelGesture();
  WheelGeometry? _geometry;
  Timer? _feedbackTimer;
  Timer? _completionTimer;
  Timer? _shuffleTimer;
  bool _disposed = false;
  bool shuffling = false;
  SubmissionResult? feedback;
  int feedbackSerial = 0;
  GameState get state => engine.state;
  bool get dragging => gesture.dragging;
  bool get interactive => state.phase == RoundPhase.playing && !shuffling;
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
      _feedbackTimer?.cancel();
      feedback = null;
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
    final result = engine.submit(ids, session: state.session);
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
        if (engine.finishCompletion(session)) refresh();
      });
    }
    notifyListeners();
  }

  void cancelPointer(int pointer) {
    if (gesture.pointer == pointer) cancelGesture();
  }

  void cancelGesture({bool notify = true}) {
    if (gesture.cancel() && notify) refresh();
  }

  void shuffle({bool reduceMotion = false}) {
    if (!interactive || dragging) return;
    if (!engine.shuffle(dragging: dragging)) return;
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
    final next = state.level.id == engine.levels.length
        ? 1
        : state.level.id + 1;
    _cancelTimers();
    gesture.cancel();
    _geometry = null;
    feedback = null;
    shuffling = false;
    engine.startLevel(next);
    notifyListeners();
  }

  void detach() {
    _cancelTimers();
    gesture.cancel();
    shuffling = false;
  }

  void _cancelTimers() {
    _feedbackTimer?.cancel();
    _completionTimer?.cancel();
    _shuffleTimer?.cancel();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelTimers();
    gesture.cancel();
    super.dispose();
  }
}
