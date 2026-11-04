import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'connection_monitor.dart';

class ApiConfig {
  static const gameId = '2e4ffdce-36d4-4461-856c-b00f083fed48';
  ApiConfig({
    required this.authUrl,
    required this.gameUrl,
    this.environment = 'local',
    this.googleClientId = const String.fromEnvironment(
      'GOOGLE_WEB_CLIENT_ID',
      defaultValue:
          '317412891641-5g9g6ag7s21djsp0f87r7cuf4a7ihcm0.apps.googleusercontent.com',
    ),
  }) {
    for (final url in [authUrl, gameUrl]) {
      if (!url.hasAuthority ||
          !['http', 'https'].contains(url.scheme) ||
          url.hasQuery ||
          url.hasFragment ||
          url.userInfo.isNotEmpty ||
          (kReleaseMode && url.scheme != 'https')) {
        throw const ApiFailure('CONFIGURATION_ERROR');
      }
    }
  }
  factory ApiConfig.environmentConfig() => ApiConfig(
    authUrl: Uri.parse(
      const String.fromEnvironment(
        'AUTH_API_URL',
        defaultValue: 'http://127.0.0.1:8081',
      ),
    ),
    gameUrl: Uri.parse(
      const String.fromEnvironment(
        'GAME_API_URL',
        defaultValue: 'http://127.0.0.1:8082',
      ),
    ),
    environment: const String.fromEnvironment(
      'API_ENVIRONMENT',
      defaultValue: 'local',
    ),
  );
  final Uri authUrl, gameUrl;
  final String environment, googleClientId;
  String get namespace => '$authUrl|$gameUrl|$environment|$gameId';
}

class ApiFailure implements Exception {
  const ApiFailure(
    this.code, {
    this.status,
    this.correlationId,
    this.retryAfter,
    this.requestNotSent = false,
  });
  final String code;
  final int? status;
  final String? correlationId;
  final int? retryAfter;
  final bool requestNotSent;
  bool get connectionFailure =>
      code == 'OFFLINE' ||
      code == 'NETWORK_ERROR' ||
      (status != null && status! >= 500 && status! < 600);
  bool get invalidAccess =>
      status == 401 &&
      ['INVALID_ACCESS_TOKEN', 'ACCESS_TOKEN_EXPIRED'].contains(code);
  String get message => switch (code) {
    'OFFLINE' =>
      'Você precisa de acesso à internet para jogar. Verifique sua conexão e tente novamente.',
    'NETWORK_ERROR' =>
      'Não foi possível conectar ao jogo. Tente novamente em instantes.',
    'SESSION_RECOVERY_REQUIRED' || 'INVALID_REFRESH_TOKEN' =>
      'Sua sessão precisa ser recuperada. Seus dados foram preservados.',
    'HINT_UNCERTAIN' =>
      'A resposta da dica não foi recebida. Ela pode ter sido cobrada. Atualize o saldo antes de comprar outra dica.',
    'INSUFFICIENT_COINS' =>
      'Você não tem moedas suficientes. Seu saldo será atualizado.',
    'CATALOG_VERSION_MISMATCH' =>
      'Atualize o aplicativo para continuar com este catálogo de palavras.',
    'DIARIO_EXPIRADO' =>
      'O desafio diário terminou. Um novo desafio está disponível.',
    'LEVEL_NOT_AVAILABLE' ||
    'LEVEL_ALREADY_COMPLETED' ||
    'DAILY_ALREADY_COMPLETED' =>
      'Seu progresso mudou. Atualize para continuar.',
    'USER_BLOCKED' ||
    'GAME_DISABLED' => 'Esta conta ou jogo está indisponível.',
    'INVALID_GOOGLE_ID_TOKEN' =>
      'Não foi possível validar o login Google. Entre novamente.',
    'GOOGLE_CANCELLED' => 'Login Google cancelado.',
    'GOOGLE_SIGN_IN_FAILED' =>
      'Não foi possível entrar no Google. Confira a conexão e a configuração do login.',
    'GOOGLE_OPERATION_EXPIRED' =>
      'A confirmação expirou. Consulte sua conta Google novamente.',
    'GOOGLE_OPERATION_IN_PROGRESS' =>
      'A confirmação está em andamento. Aguarde alguns segundos e retome.',
    'GOOGLE_TOKEN_MISMATCH' ||
    'GOOGLE_CHOICE_CONFLICT' ||
    'GOOGLE_LINK_CHANGED' ||
    'GOOGLE_ACCOUNT_EXISTS' ||
    'ACCOUNT_CONFLICT' =>
      'O vínculo mudou. Consulte as contas novamente antes de escolher.',
    'RATE_LIMIT_EXCEEDED' =>
      'Muitas tentativas. Aguarde um minuto para tentar novamente.',
    'CONFIGURATION_ERROR' => 'Confira a configuração de conexão do aplicativo.',
    'VALIDATION_ERROR' => 'Confira os dados informados e tente novamente.',
    'PLAYER_NAME_TAKEN' => 'Esse nome de jogador já existe. Tente outro.',
    'SHOP_UNAVAILABLE' => 'A loja ainda não está disponível.',
    _ =>
      status == 503
          ? 'Serviço temporariamente indisponível. Tente novamente.'
          : 'Não foi possível concluir a operação. Tente novamente.',
  };
  @override
  String toString() => message;
}

/// No retries: a transport failure never proves a mutation was rolled back.
class ApiClient {
  ApiClient(
    this.config, {
    http.Client? client,
    this.connection,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();
  final ApiConfig config;
  final http.Client _client;
  final Duration timeout;
  final ConnectionMonitor? connection;

  Future<void> checkConnection() async {
    await connection?.start();
    if (connection?.internetAvailable == false) {
      throw const ApiFailure('OFFLINE', requestNotSent: true);
    }
  }

  Never _networkFailure() {
    connection?.reportServiceFailure();
    throw ApiFailure(
      connection?.internetAvailable == false ? 'OFFLINE' : 'NETWORK_ERROR',
    );
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    bool authService = false,
    String? bearer,
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    await checkConnection();
    final base = authService ? config.authUrl : config.gameUrl;
    final uri = base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/$'), '')}$path',
      queryParameters: query,
    );
    try {
      final request = http.Request(method, uri)
        ..headers['Accept'] = 'application/json, application/problem+json';
      request.followRedirects = false;
      if (bearer != null) request.headers['Authorization'] = 'Bearer $bearer';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(timeout);
      Map<String, dynamic>? json;
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) json = decoded;
      } on FormatException {
        /* Status still identifies non-JSON failures. */
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode >= 500) connection?.reportServiceFailure();
        throw ApiFailure(
          json?['code'] as String? ?? 'HTTP_ERROR',
          status: response.statusCode,
          correlationId:
              json?['correlationId'] as String? ??
              response.headers['x-correlation-id'],
          retryAfter: int.tryParse(response.headers['retry-after'] ?? ''),
        );
      }
      if (json == null) throw const ApiFailure('INVALID_RESPONSE');
      return json;
    } on TimeoutException {
      _networkFailure();
    } on SocketException {
      _networkFailure();
    } on http.ClientException {
      _networkFailure();
    }
  }

  void close() => _client.close();
}
