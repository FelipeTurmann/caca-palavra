import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';

abstract interface class CredentialStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore(String namespace)
    : key = 'api_session_v1_${base64Url.encode(utf8.encode(namespace))}';
  final String key;
  static const _storage = FlutterSecureStorage();
  @override
  Future<String?> read() => _storage.read(key: key);
  @override
  Future<void> write(String value) => _storage.write(key: key, value: value);
}

String installationUuid() {
  final r = Random.secure();
  final bytes = List.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class AuthSession {
  AuthSession(this.api, this.store, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final ApiClient api;
  final CredentialStore store;
  final DateTime Function() now;
  Map<String, dynamic> _saved = {};
  Future<void>? _refreshing;
  Future<void>? _ensuring;
  String get userId => (_saved['tokens'] as Map)['idUsuario'] as String;
  String get accessToken => (_saved['tokens'] as Map)['accessToken'] as String;
  bool get needsRecovery =>
      _saved['refreshPending'] == true || _saved['invalid'] == true;
  Map<String, dynamic>? get googleOperation => _saved['google'] == null
      ? null
      : Map<String, dynamic>.from(_saved['google'] as Map);
  Future<void> _save(Map<String, dynamic> value) async {
    await store.write(jsonEncode(value));
    _saved = value;
  }

  Future<void> restore() async {
    final raw = await store.read();
    _saved = raw == null
        ? {}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> ensure() =>
      _ensuring ??= _ensure().whenComplete(() => _ensuring = null);
  Future<void> _ensure() async {
    await api.checkConnection();
    if (_refreshing != null) {
      await _refreshing;
      return;
    }
    if (_saved['tokens'] == null) {
      // Persist installation before making a request that creates an identity.
      await _save({
        ..._saved,
        'installationId': _saved['installationId'] ?? installationUuid(),
      });
      await accept(
        await api.request(
          'POST',
          '/api/v1/auth/anonymous',
          authService: true,
          body: {
            'idJogo': ApiConfig.gameId,
            'installationId': _saved['installationId'],
          },
        ),
      );
    } else {
      if (needsRecovery) throw const ApiFailure('SESSION_RECOVERY_REQUIRED');
      final expires = DateTime.parse(_saved['expiresAt'] as String);
      if (!expires.isAfter(now().add(const Duration(seconds: 30)))) {
        await refresh();
      }
    }
  }

  Future<void> accept(Map<String, dynamic> tokens) async {
    if (tokens['idUsuario'] is! String ||
        tokens['accessToken'] is! String ||
        tokens['refreshToken'] is! String ||
        tokens['expiresIn'] is! num ||
        tokens['tokenType'] != 'Bearer') {
      throw const ApiFailure('INVALID_RESPONSE');
    }
    await _save({
      ..._saved,
      'tokens': tokens,
      'expiresAt': now()
          .add(Duration(seconds: (tokens['expiresIn'] as num).toInt()))
          .toIso8601String(),
      'refreshPending': false,
      'invalid': false,
    });
  }

  Future<void> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  Future<void> _refresh() async {
    if (needsRecovery) throw const ApiFailure('SESSION_RECOVERY_REQUIRED');
    await api.checkConnection();
    await _save({..._saved, 'refreshPending': true});
    try {
      final tokens = await api.request(
        'POST',
        '/api/v1/auth/refresh',
        authService: true,
        body: {
          'idJogo': ApiConfig.gameId,
          'refreshToken': (_saved['tokens'] as Map)['refreshToken'],
        },
      );
      if (tokens['idUsuario'] != userId) {
        throw const ApiFailure('INVALID_RESPONSE');
      }
      await accept(tokens);
    } on ApiFailure catch (e) {
      // A definitive rejection is known not to have rotated the token.
      if (e.requestNotSent ||
          (e.status != null && e.status! >= 400 && e.status! < 500)) {
        await _save({
          ..._saved,
          'refreshPending': false,
          'invalid': e.code == 'INVALID_REFRESH_TOKEN',
        });
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> authorized(
    String method,
    String path, {
    bool authService = false,
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    await ensure();
    final usedToken = accessToken;
    try {
      return await api.request(
        method,
        path,
        authService: authService,
        bearer: usedToken,
        body: body,
        query: query,
      );
    } on ApiFailure catch (e) {
      if (!e.invalidAccess) rethrow;
      // Only explicit authentication rejection is retried. No economic effect ran.
      if (accessToken == usedToken) await refresh();
      return api.request(
        method,
        path,
        authService: authService,
        bearer: accessToken,
        body: body,
        query: query,
      );
    }
  }

  Future<void> saveGoogle(Map<String, dynamic> operation) =>
      _save({..._saved, 'google': operation});
  Future<void> clearGoogle() => _save({..._saved}..remove('google'));

  /// Only an explicit recovery action may replace unusable anonymous credentials.
  Future<void> createRecoveryIdentity() async {
    await _save(
      {
        ..._saved,
        'previousUser': _saved['tokens']?['idUsuario'],
        'tokens': null,
        'refreshPending': false,
        'invalid': false,
      }..remove('google'),
    );
    await ensure();
  }
}
