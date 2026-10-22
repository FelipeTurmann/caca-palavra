import 'campaign_models.dart';

class CoinPackage {
  const CoinPackage(this.id, this.amount, this.price);
  final String id, price;
  final int amount;
}

abstract final class ShopCatalog {
  static const packages = [
    CoinPackage('coins_500', 500, 'R\$ 3,99'),
    CoinPackage('coins_1000', 1000, 'R\$ 5,99'),
    CoinPackage('coins_2500', 2500, 'R\$ 10,99'),
    CoinPackage('coins_5000', 5000, 'R\$ 18,99'),
  ];
  static CoinPackage find(String id) => packages.firstWhere(
    (p) => p.id == id,
    orElse: () => throw ArgumentError('Pacote inválido.'),
  );
}

class ProviderReceipt {
  const ProviderReceipt(
    this.orderId,
    this.source,
    this.amount, {
    this.packageId,
  });
  final String orderId, source;
  final int amount;
  final String? packageId;
  Map<String, Object?> toJson() => {
    'orderId': orderId,
    'source': source,
    'amount': amount,
    'packageId': packageId,
    'simulated': true,
  };
}

abstract interface class PurchaseProvider {
  Future<ProviderReceipt> purchase(String orderId, CoinPackage package);
}

abstract interface class RewardAdProvider {
  Future<ProviderReceipt> reward(String orderId);
}

class SimulatedPurchaseProvider implements PurchaseProvider {
  @override
  Future<ProviderReceipt> purchase(String orderId, CoinPackage package) async =>
      ProviderReceipt(
        orderId,
        'simulated_purchase',
        package.amount,
        packageId: package.id,
      );
}

class SimulatedRewardAdProvider implements RewardAdProvider {
  @override
  Future<ProviderReceipt> reward(String orderId) async =>
      ProviderReceipt(orderId, 'simulated_ad', Economy.adReward);
}
