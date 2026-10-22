import 'dart:async';
import 'package:flutter/services.dart';
import '../preferences/player_preferences.dart';

enum FeedbackCue {
  select,
  undo,
  shuffle,
  correct,
  extra,
  invalid,
  reveal,
  victory,
  coins,
}

abstract interface class FeedbackOutput {
  Future<void> prepare();
  Future<void> sound(FeedbackCue cue);
  Future<void> haptic({required bool success});
  Future<void> stop();
  Future<void> dispose();
}

class SilentFeedbackOutput implements FeedbackOutput {
  @override
  Future<void> prepare() async {}
  @override
  Future<void> sound(FeedbackCue cue) async {}
  @override
  Future<void> haptic({required bool success}) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class AndroidFeedbackOutput implements FeedbackOutput {
  static const channel = MethodChannel('conecte_palavras/feedback');
  @override
  Future<void> prepare() => channel.invokeMethod<void>('prepare');
  @override
  Future<void> sound(FeedbackCue cue) =>
      channel.invokeMethod<void>('sound', cue.name);
  @override
  Future<void> haptic({required bool success}) =>
      channel.invokeMethod<void>('haptic', success);
  @override
  Future<void> stop() => channel.invokeMethod<void>('stop');
  @override
  Future<void> dispose() => channel.invokeMethod<void>('dispose');
}

/// Presentation only. No callback from this service changes the game or wallet.
class FeedbackCoordinator {
  FeedbackCoordinator(
    this.preferences,
    this.output, {
    Duration Function()? elapsed,
  }) : elapsed = elapsed ?? _clock() {
    _sound = preferences.value.sound;
    preferences.addListener(_settingsChanged);
  }
  static Duration Function() _clock() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  final PreferencesController preferences;
  final FeedbackOutput output;
  final Duration Function() elapsed;
  final Set<String> _consumed = {};
  Duration? _lastSelection;
  Duration _importantUntil = Duration.zero;
  bool active = true, _disposed = false, _sound = true;
  Future<void> _ignore(Future<void> Function() work) async {
    try {
      await work();
    } catch (_) {
      /* Media is optional; never block a command. */
    }
  }

  Future<void> prepare() => _ignore(output.prepare);
  void _settingsChanged() {
    if (_sound && !preferences.value.sound) unawaited(_ignore(output.stop));
    _sound = preferences.value.sound;
  }

  void emit(FeedbackCue cue, {String? id}) {
    if (_disposed) return;
    if (id != null && !_consumed.add(id)) return;
    if (!active) return;
    final time = elapsed();
    final selection = cue == FeedbackCue.select || cue == FeedbackCue.undo;
    if (selection &&
        (time < _importantUntil ||
            (_lastSelection != null &&
                time - _lastSelection! < const Duration(milliseconds: 50)))) {
      return;
    }
    if (selection) _lastSelection = time;
    if (cue == FeedbackCue.victory || cue == FeedbackCue.reveal) {
      _importantUntil = time + const Duration(milliseconds: 400);
    }
    if (preferences.value.sound) unawaited(_ignore(() => output.sound(cue)));
    final vibrate = cue != FeedbackCue.undo && cue != FeedbackCue.invalid;
    if (preferences.value.haptics && vibrate) {
      unawaited(
        _ignore(
          () => output.haptic(
            success:
                cue == FeedbackCue.correct ||
                cue == FeedbackCue.extra ||
                cue == FeedbackCue.reveal ||
                cue == FeedbackCue.victory,
          ),
        ),
      );
    }
  }

  void suspend() {
    active = false;
    _lastSelection = null;
    unawaited(_ignore(output.stop));
  }

  void resume() {
    if (!_disposed) active = true;
  }

  void dispose() {
    _disposed = true;
    preferences.removeListener(_settingsChanged);
    unawaited(_ignore(output.dispose));
  }
}
