import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract interface class NetworkAccessSource {
  Future<bool?> check();
  Stream<bool?> get changes;
}

class AndroidNetworkAccessSource implements NetworkAccessSource {
  static const _methods = MethodChannel('conecte_palavras/network');
  static const _events = EventChannel('conecte_palavras/network_changes');

  @override
  Future<bool?> check() async {
    try {
      return await _methods.invokeMethod<bool>('check');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Stream<bool?> get changes => _events.receiveBroadcastStream().cast<bool?>();
}

enum ConnectionProblem { offline, serviceUnavailable }

/// Network recovery only verifies access; it never repeats game mutations.
class ConnectionMonitor extends ChangeNotifier {
  ConnectionMonitor(this.source);
  final NetworkAccessSource source;
  bool? internetAvailable;
  ConnectionProblem? problem;
  bool checking = false;
  bool _disposed = false;
  int _networkRevision = 0;
  StreamSubscription<bool?>? _subscription;
  Future<void>? _starting;
  bool get blocked => problem != null;

  Future<void> start() => _starting ??= _start();

  Future<void> _start() async {
    _subscription = source.changes.listen(
      _networkChanged,
      onError: (Object _) {
        /* Unknown state: API access remains authoritative. */
      },
    );
    await refreshNetwork();
  }

  Future<void> refreshNetwork() async {
    final revision = _networkRevision;
    final available = await source.check();
    if (!_disposed && revision == _networkRevision) _networkChanged(available);
  }

  void _networkChanged(bool? available) {
    if (_disposed) return;
    _networkRevision++;
    internetAvailable = available;
    if (available == false) {
      problem = ConnectionProblem.offline;
    } else if (problem == ConnectionProblem.offline) {
      // A network returning does not prove that both APIs can be reached.
      problem = ConnectionProblem.serviceUnavailable;
    }
    notifyListeners();
  }

  void reportServiceFailure() {
    if (_disposed) return;
    problem = internetAvailable == false
        ? ConnectionProblem.offline
        : ConnectionProblem.serviceUnavailable;
    notifyListeners();
  }

  Future<void> retry(Future<bool> Function() verifyServices) async {
    if (checking || _disposed) return;
    checking = true;
    notifyListeners();
    try {
      await start();
      await refreshNetwork();
      if (internetAvailable == false) return;
      final verified = await verifyServices();
      if (!_disposed && verified && internetAvailable != false) problem = null;
    } finally {
      checking = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
