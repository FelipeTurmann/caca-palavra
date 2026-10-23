import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../theme/visual_theme_catalog.dart';

enum Introduction { unseen, inProgress, completed, skipped, exempted }

@immutable
class PlayerPreferences {
  const PlayerPreferences({
    this.sound = true,
    this.haptics = true,
    this.reduceMotion = false,
    this.introduction = Introduction.unseen,
    this.visualThemeId = 'jardim_gatinho',
  });
  final bool sound, haptics, reduceMotion;
  final Introduction introduction;
  final String visualThemeId;
  VisualTheme get visualTheme => VisualTheme.resolve(visualThemeId);
  bool get needsIntroduction =>
      introduction == Introduction.unseen ||
      introduction == Introduction.inProgress;
  PlayerPreferences copyWith({
    bool? sound,
    bool? haptics,
    bool? reduceMotion,
    Introduction? introduction,
    String? visualThemeId,
  }) => PlayerPreferences(
    sound: sound ?? this.sound,
    haptics: haptics ?? this.haptics,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    introduction: introduction ?? this.introduction,
    visualThemeId: visualThemeId ?? this.visualThemeId,
  );
  Map<String, Object> toRow() => {
    'id': 'local',
    'sound': sound ? 1 : 0,
    'haptics': haptics ? 1 : 0,
    'reduce_motion': reduceMotion ? 1 : 0,
    'introduction': introduction.name,
    'visual_theme_id': visualThemeId,
  };
  factory PlayerPreferences.fromRow(Map<String, Object?> row) =>
      PlayerPreferences(
        sound: row['sound'] == 1,
        haptics: row['haptics'] == 1,
        reduceMotion: row['reduce_motion'] == 1,
        introduction: Introduction.values.byName(row['introduction'] as String),
        visualThemeId: VisualTheme.resolve(
          row['visual_theme_id'] as String?,
        ).id,
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
  bool saving = false;
  bool themeSaved = false;
  bool _themeDirty = false;
  bool get savingTheme => saving && _themeDirty;
  void clearThemeNotice() {
    themeSaved = false;
  }

  Future<void> selectTheme(VisualTheme theme) {
    if (value.visualTheme == theme) return Future.value();
    _themeDirty = true;
    themeSaved = false;
    return update(value.copyWith(visualThemeId: theme.id));
  }

  Future<void> _tail = Future.value();
  int _revision = 0;
  bool _disposed = false;
  Future<void> update(PlayerPreferences next) {
    value = next;
    error = null;
    saving = true;
    if (_themeDirty) themeSaved = false;
    final revision = ++_revision;
    notifyListeners();
    _tail = _tail.then((_) async {
      try {
        await store.write(next);
        if (revision == _revision) {
          error = null;
          saving = false;
          if (_themeDirty) {
            themeSaved = true;
            _themeDirty = false;
          }
        }
      } catch (_) {
        if (revision == _revision) {
          saving = false;
          error = _themeDirty
              ? 'Não foi possível salvar o tema. Tente novamente.'
              : 'Não foi possível salvar esta preferência. Tente novamente.';
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
