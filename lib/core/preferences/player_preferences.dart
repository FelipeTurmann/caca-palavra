import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

enum Introduction { unseen, inProgress, completed, skipped, exempted }

@immutable
class PlayerPreferences {
  const PlayerPreferences({
    this.sound = true,
    this.haptics = true,
    this.reduceMotion = false,
    this.introduction = Introduction.unseen,
  });
  final bool sound, haptics, reduceMotion;
  final Introduction introduction;
  bool get needsIntroduction =>
      introduction == Introduction.unseen ||
      introduction == Introduction.inProgress;
  PlayerPreferences copyWith({
    bool? sound,
    bool? haptics,
    bool? reduceMotion,
    Introduction? introduction,
  }) => PlayerPreferences(
    sound: sound ?? this.sound,
    haptics: haptics ?? this.haptics,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    introduction: introduction ?? this.introduction,
  );
  Map<String, Object> toRow() => {
    'id': 'local',
    'sound': sound ? 1 : 0,
    'haptics': haptics ? 1 : 0,
    'reduce_motion': reduceMotion ? 1 : 0,
    'introduction': introduction.name,
  };
  factory PlayerPreferences.fromRow(Map<String, Object?> row) =>
      PlayerPreferences(
        sound: row['sound'] == 1,
        haptics: row['haptics'] == 1,
        reduceMotion: row['reduce_motion'] == 1,
        introduction: Introduction.values.byName(row['introduction'] as String),
      );
}

abstract interface class PreferencesStore {
  Future<PlayerPreferences> read();
  Future<void> write(PlayerPreferences value);
}

class SqlitePreferencesStore implements PreferencesStore {
  SqlitePreferencesStore(this.database);
  final Database database;
  @override
  Future<PlayerPreferences> read() async => PlayerPreferences.fromRow(
    (await database.query(
      'app_settings',
      where: 'id = ?',
      whereArgs: ['local'],
    )).single,
  );
  @override
  Future<void> write(PlayerPreferences value) async {
    await database.update(
      'app_settings',
      value.toRow(),
      where: 'id = ?',
      whereArgs: ['local'],
    );
  }
}

class MemoryPreferencesStore implements PreferencesStore {
  MemoryPreferencesStore([
    this.value = const PlayerPreferences(introduction: Introduction.exempted),
  ]);
  PlayerPreferences value;
  @override
  Future<PlayerPreferences> read() async => value;
  @override
  Future<void> write(PlayerPreferences value) async {
    this.value = value;
  }
}

class PreferencesController extends ChangeNotifier {
  PreferencesController(this.store, this.value);
  factory PreferencesController.memory() => PreferencesController(
    MemoryPreferencesStore(),
    const PlayerPreferences(introduction: Introduction.exempted),
  );
  static Future<PreferencesController> load(PreferencesStore store) async =>
      PreferencesController(store, await store.read());
  final PreferencesStore store;
  PlayerPreferences value;
  String? error;
  Future<void> _tail = Future.value();
  int _revision = 0;
  bool _disposed = false;
  Future<void> update(PlayerPreferences next) {
    value = next;
    error = null;
    final revision = ++_revision;
    notifyListeners();
    _tail = _tail.then((_) async {
      try {
        await store.write(next);
        if (revision == _revision) error = null;
      } catch (_) {
        if (revision == _revision) {
          error = 'Não foi possível salvar esta preferência. Tente novamente.';
        }
      }
      if (!_disposed) notifyListeners();
    });
    return _tail;
  }

  Future<void> retry() => update(value);
  Future<void> flush() => _tail;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
