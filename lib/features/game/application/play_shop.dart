import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/api/api_client.dart';
import '../data/api_progress_repository.dart';

class PlayOffer {
  const PlayOffer(this.name, this.adFree, this.details);

  final String name;
  final bool adFree;
  final ProductDetails details;
}

class PlayShop extends ChangeNotifier {
  PlayShop(this._repository, this._refreshPlayer, {InAppPurchase? billing})
    : _billing = billing ?? InAppPurchase.instance {
    _subscription = _billing.purchaseStream.listen(
      (purchases) => unawaited(_handle(purchases)),
      onError: (Object _) {
        _openingPayment = false;
        _message = 'Não foi possível receber o resultado do Google Play.';
        _notify();
      },
    );
  }

  final ApiProgressRepository _repository;
  final Future<void> Function() _refreshPlayer;
  final InAppPurchase _billing;
  late final StreamSubscription<List<PurchaseDetails>> _subscription;
  final _processing = <String>{};
  final _delivered = <String>{};
  bool _disposed = false;
  bool _loading = false;
  bool _openingPayment = false;
  bool _restoring = false;
  bool _enabled = false;
  String? _account;
  String? _message;
  List<PlayOffer> _offers = const [];

  bool get busy => _openingPayment || _processing.isNotEmpty || _restoring;
  bool get loading => _loading;
  bool get enabled => _enabled;
  String? get message => _message;
  List<PlayOffer> get offers => _offers;

  Future<void> prepare() async {
    await load();
    await restore();
  }

  Future<void> load() async {
    if (_disposed || _loading || busy) return;
    _loading = true;
    _offers = const [];
    _message = null;
    _notify();
    try {
      final catalog = await _repository.call('GET', '/api/v1/pacotes');
      _account = catalog['contaCompra'] as String?;
      _enabled = catalog['comprasHabilitadas'] == true && _account != null;
      if (!_enabled) {
        _message = 'Compras indisponíveis no momento.';
        return;
      }
      if (!await _billing.isAvailable()) {
        _enabled = false;
        _message = 'O Google Play não está disponível neste dispositivo.';
        return;
      }
      final products = <String, Map<String, dynamic>>{
        for (final item
            in (catalog['pacotes'] as List).cast<Map<String, dynamic>>())
          if (item['codigoProdutoLoja'] is String)
            item['codigoProdutoLoja'] as String: item,
      };
      if (products.isEmpty) return;
      final response = await _billing.queryProductDetails(
        products.keys.toSet(),
      );
      if (response.error != null) {
        _message = 'Não foi possível consultar os preços do Google Play.';
        return;
      }
      final details = <String, ProductDetails>{};
      for (final item in response.productDetails) {
        details.putIfAbsent(item.id, () => item);
      }
      _offers = [
        for (final entry in products.entries)
          if (details[entry.key] case final product?)
            PlayOffer(
              entry.value['nome'] as String,
              entry.value['tipo'] == 'SEM_AD',
              product,
            ),
      ];
      if (_offers.isEmpty) {
        _message = 'Nenhum produto disponível no Google Play.';
      }
    } catch (_) {
      _enabled = false;
      _message = 'Não foi possível carregar a loja. Tente novamente.';
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> buy(PlayOffer offer) async {
    final account = _account;
    if (_disposed ||
        busy ||
        loading ||
        !enabled ||
        account == null ||
        !_offers.contains(offer)) {
      return;
    }
    _openingPayment = true;
    _message = null;
    _notify();
    final param = PurchaseParam(
      productDetails: offer.details,
      applicationUserName: account,
    );
    try {
      final opened = offer.adFree
          ? await _billing.buyNonConsumable(purchaseParam: param)
          : await _billing.buyConsumable(
              purchaseParam: param,
              autoConsume: false,
            );
      if (!opened) _couldNotOpenPayment();
    } catch (_) {
      _couldNotOpenPayment();
    }
  }

  void _couldNotOpenPayment() {
    _openingPayment = false;
    _message =
        'O Google Play não abriu a compra. Verifique suas compras e tente novamente.';
    _notify();
  }

  Future<void> restore() async {
    if (_disposed || !_enabled || _restoring) return;
    _restoring = true;
    _notify();
    try {
      // O Google mantém as compras sem consumo/confirmação disponíveis para consulta.
      await _billing.restorePurchases();
    } catch (_) {
      _message = 'Não foi possível verificar as compras no Google Play.';
    } finally {
      _restoring = false;
      _openingPayment = false;
      _notify();
    }
  }

  Future<void> _handle(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (_disposed) return;
      _openingPayment = false;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _message = 'Aguardando a confirmação do pagamento pelo Google Play.';
        case PurchaseStatus.canceled:
          _message = 'Compra cancelada.';
        case PurchaseStatus.error:
          _message = 'Não foi possível concluir a compra no Google Play.';
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verify(purchase);
      }
      _notify();
    }
  }

  Future<void> _verify(PurchaseDetails purchase) async {
    final token = purchase.verificationData.serverVerificationData;
    if (purchase.verificationData.source != 'google_play' ||
        token.isEmpty ||
        _delivered.contains(token) ||
        !_processing.add(token)) {
      return;
    }
    _notify();
    try {
      final result = await _repository.call(
        'POST',
        '/api/v1/compras/google-play/validar',
        body: {'purchaseToken': token},
      );
      if (result['estado'] == 'PENDENTE') {
        _message = 'Aguardando a confirmação do pagamento pelo Google Play.';
        return;
      }
      if (result['estado'] != 'ENTREGUE') {
        throw const ApiFailure('INVALID_RESPONSE');
      }
      _delivered.add(token);
      // Consumo e confirmação ficam no servidor, após a entrega persistida.
      if (_disposed) return;
      await _refreshPlayer();
      _message = result['semAnuncios'] == true
          ? 'Benefício sem anúncios ativado.'
          : 'Compra confirmada. As moedas foram entregues.';
    } on ApiFailure catch (failure) {
      if (failure.code == 'PLAY_PURCHASE_OWNER_MISMATCH' &&
          purchase.status == PurchaseStatus.restored) {
        return;
      }
      _message = switch (failure.code) {
        'PLAY_PURCHASE_OWNER_MISMATCH' =>
          'Esta compra pertence a outro perfil do jogo.',
        'PLAY_PURCHASE_INVALID' || 'PLAY_PURCHASE_NOT_ELIGIBLE' =>
          'O Google Play não confirmou esta compra.',
        _ =>
          'Não foi possível validar a compra. Use Verificar compras para tentar novamente.',
      };
    } catch (_) {
      _message =
          'Não foi possível validar a compra. Use Verificar compras para tentar novamente.';
    } finally {
      _processing.remove(token);
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
