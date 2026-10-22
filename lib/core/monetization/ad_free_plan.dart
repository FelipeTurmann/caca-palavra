import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// Prototype entitlement, deliberately separate from any real purchase receipt.
abstract interface class AdFreePlanStore {
  Future<bool> read();
  Future<void> activate();
}

class SqliteAdFreePlanStore implements AdFreePlanStore {
  SqliteAdFreePlanStore(this.database);
  final Database database;
  static const id = 'ad_free_simulated_v1';
  @override
  Future<bool> read() async => (await database.query(
    'simulated_entitlements',
    where: 'id = ?',
    whereArgs: [id],
  )).isNotEmpty;
  @override
  Future<void> activate() async {
    await database.insert('simulated_entitlements', {
      'id': id,
      'activated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}

class MemoryAdFreePlanStore implements AdFreePlanStore {
  bool active = false;
  @override
  Future<bool> read() async => active;
  @override
  Future<void> activate() async {
    active = true;
  }
}

class AdFreePlanController extends ChangeNotifier {
  AdFreePlanController(this.store, this.active);
  factory AdFreePlanController.memory() =>
      AdFreePlanController(MemoryAdFreePlanStore(), false);
  static Future<AdFreePlanController> load(AdFreePlanStore store) async =>
      AdFreePlanController(store, await store.read());
  final AdFreePlanStore store;
  bool active;
  bool busy = false;
  String? error;
  bool _disposed = false;
  Future<void>? _pending;

  Future<void> activateSimulated() {
    if (_pending != null) return _pending!;
    if (active || _disposed) return Future.value();
    busy = true;
    error = null;
    notifyListeners();
    return _pending = _activate();
  }

  Future<void> _activate() async {
    try {
      await store.activate();
      active = true;
    } catch (_) {
      error = 'Não foi possível salvar a ativação. Tente novamente.';
    } finally {
      busy = false;
      _pending = null;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> flush() async {
    await _pending;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
