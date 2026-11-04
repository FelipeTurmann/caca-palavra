import 'package:google_sign_in/google_sign_in.dart';

import 'api_client.dart';
import 'auth_session.dart';

abstract interface class GoogleIdentityProvider {
  Future<String> idToken();
}

class GoogleSdkIdentityProvider implements GoogleIdentityProvider {
  GoogleSdkIdentityProvider(this.clientId);
  final String clientId;
  static Future<void>? _initializing;
  @override
  Future<String> idToken() async {
    try {
      await (_initializing ??= GoogleSignIn.instance.initialize(
        serverClientId: clientId,
      ));
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw const ApiFailure('INVALID_GOOGLE_ID_TOKEN');
      return token;
    } on GoogleSignInException catch (e) {
      throw ApiFailure(
        e.code == GoogleSignInExceptionCode.canceled
            ? 'GOOGLE_CANCELLED'
            : 'GOOGLE_SIGN_IN_FAILED',
      );
    }
  }
}

class GoogleLink {
  GoogleLink(this.session, this.provider);
  final AuthSession session;
  final GoogleIdentityProvider provider;
  Future<Map<String, dynamic>> consult({
    void Function()? onIdentitySelected,
  }) async {
    final proof = await provider.idToken();
    onIdentitySelected?.call();
    final lookup = await session.authorized(
      'POST',
      '/api/v1/contas/google/consultar',
      body: {'googleIdToken': proof},
    );
    await session.saveGoogle({
      'codigoOperacao': lookup['codigoOperacao'],
      'expiraEm': lookup['expiraEm'],
      'googleIdToken': proof,
      'lookup': lookup,
      'owner': session.userId,
      'started': false,
    });
    return lookup;
  }

  Future<void> confirm(String keep) async {
    final pending = session.googleOperation!;
    if (pending['manter'] != null && pending['manter'] != keep) {
      throw const ApiFailure('GOOGLE_CHOICE_CONFLICT', status: 409);
    }
    final op = {...pending, 'manter': keep, 'started': true};
    await session.saveGoogle(op);
    final tokens = await session.authorized(
      'POST',
      '/api/v1/contas/google/confirmar',
      body: {
        'codigoOperacao': op['codigoOperacao'],
        'manter': keep,
        'googleIdToken': op['googleIdToken'],
      },
    );
    await session.accept(tokens);
    await session.clearGoogle();
  }

  Future<void> resume() async {
    final op = session.googleOperation;
    if (op == null || op['started'] != true) {
      throw const ApiFailure('GOOGLE_OPERATION_NOT_STARTED', status: 409);
    }
    Map<String, dynamic> tokens;
    try {
      // Deliberately bypass authorized(): the previous account may be disabled.
      tokens = await session.api.request(
        'POST',
        '/api/v1/contas/google/retomar',
        body: {
          'codigoOperacao': op['codigoOperacao'],
          'googleIdToken': op['googleIdToken'],
        },
      );
    } on ApiFailure catch (e) {
      if (e.code == 'GOOGLE_OPERATION_NOT_STARTED' &&
          !session.needsRecovery &&
          session.userId == op['owner']) {
        await confirm(op['manter'] as String);
        return;
      }
      rethrow;
    }
    await session.accept(tokens);
    await session.clearGoogle();
  }
}
