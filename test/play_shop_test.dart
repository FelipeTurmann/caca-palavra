import 'dart:async';

import 'package:caca_palavra/core/api/api_client.dart';
import 'package:caca_palavra/features/game/application/play_shop.dart';
import 'package:caca_palavra/features/game/data/api_progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

const sku = 'coins_100';
const account = 'perfil-opaco';

class _Repository implements ApiProgressRepository {
  final verified = <String>[];
  bool failOnce = false;

  @override
  Future<Map<String, dynamic>> call(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (method == 'GET' && path == '/api/v1/pacotes') {
      return {
        'comprasHabilitadas': true,
        'contaCompra': account,
        'pacotes': [
          {'codigoProdutoLoja': sku, 'nome': '100 moedas', 'tipo': 'MOEDAS'},
        ],
      };
    }
    expect(method, 'POST');
    expect(path, '/api/v1/compras/google-play/validar');
    expect(body!.keys, ['purchaseToken']);
    verified.add(body['purchaseToken'] as String);
    if (failOnce) {
      failOnce = false;
      throw const ApiFailure('NETWORK_ERROR');
    }
    return {'estado': 'ENTREGUE', 'semAnuncios': false};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Billing implements InAppPurchase {
  final events = StreamController<List<PurchaseDetails>>.broadcast();
  PurchaseParam? params;
  bool? consumedAutomatically;
  PurchaseDetails? restorable;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => events.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    expect(ids, {sku});
    return ProductDetailsResponse(
      productDetails: [
        ProductDetails(
          id: sku,
          title: '100 moedas',
          description: 'Pacote de moedas',
          price: 'R\$ 1,00',
          rawPrice: 1,
          currencyCode: 'BRL',
        ),
      ],
      notFoundIDs: [],
    );
  }

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    params = purchaseParam;
    consumedAutomatically = autoConsume;
    return true;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    if (restorable case final purchase?) events.add([purchase]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PurchaseDetails _purchase(PurchaseStatus status) => PurchaseDetails(
  productID: sku,
  verificationData: PurchaseVerificationData(
    localVerificationData: 'local-data',
    serverVerificationData: 'google-receipt',
    source: 'google_play',
  ),
  transactionDate: null,
  status: status,
);

Future<void> _drain() => Future<void>.delayed(Duration.zero);

void main() {
  test('usa preço do Google e valida só depois do pagamento', () async {
    final repository = _Repository();
    final billing = _Billing();
    var refreshes = 0;
    final shop = PlayShop(
      repository,
      () async => refreshes++,
      billing: billing,
    );
    addTearDown(() async {
      shop.dispose();
      await billing.events.close();
    });

    await shop.load();
    expect(shop.offers.single.details.price, 'R\$ 1,00');
    await shop.buy(shop.offers.single);
    expect(billing.params!.applicationUserName, account);
    expect(billing.consumedAutomatically, false);

    billing.events.add([_purchase(PurchaseStatus.pending)]);
    await _drain();
    expect(repository.verified, isEmpty);
    expect(refreshes, 0);

    billing.events.add([
      _purchase(PurchaseStatus.purchased),
      _purchase(PurchaseStatus.purchased),
    ]);
    await _drain();
    expect(repository.verified, ['google-receipt']);
    expect(refreshes, 1);
  });

  test('reenvia o mesmo token pela consulta após falha de rede', () async {
    final repository = _Repository()..failOnce = true;
    final billing = _Billing();
    var refreshes = 0;
    final shop = PlayShop(
      repository,
      () async => refreshes++,
      billing: billing,
    );
    addTearDown(() async {
      shop.dispose();
      await billing.events.close();
    });

    await shop.load();
    billing.events.add([_purchase(PurchaseStatus.purchased)]);
    await _drain();
    expect(refreshes, 0);

    billing.restorable = _purchase(PurchaseStatus.restored);
    await shop.restore();
    await _drain();
    expect(repository.verified, ['google-receipt', 'google-receipt']);
    expect(refreshes, 1);
  });
}
