import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../features/game/application/campaign_models.dart';
import '../../features/game/application/shop_models.dart';

/// A small SDK boundary lets tests exercise the ad lifecycle without a network.
abstract interface class RewardAdGateway {
  Future<LoadedRewardAd> load();
}

abstract interface class LoadedRewardAd {
  Future<void> show({
    required VoidCallback onEarned,
    required VoidCallback onDismissed,
    required VoidCallback onFailed,
  });
  void dispose();
}

/// Deliberately uses Google's Android demo unit, including in release builds.
/// No production identifier or automatic ad placement is configured.
class AdMobTestRewardAdProvider implements RewardAdProvider {
  AdMobTestRewardAdProvider({RewardAdGateway? gateway})
    : gateway = gateway ?? GoogleRewardAdGateway();

  final RewardAdGateway gateway;
  final Map<String, ProviderReceipt> _earned = {};
  Future<ProviderReceipt>? _inFlight;
  String? _activeOrder;

  @override
  String get source => 'admob_test';

  @override
  Future<ProviderReceipt> reward(String orderId) {
    if (_earned.containsKey(orderId)) return Future.value(_earned[orderId]!);
    if (_inFlight != null) {
      if (_activeOrder == orderId) return _inFlight!;
      return Future.error(
        const RewardAdException('Já existe um anúncio em andamento.'),
      );
    }
    _activeOrder = orderId;
    return _inFlight = _watch(orderId).whenComplete(() {
      _activeOrder = null;
      _inFlight = null;
    });
  }

  Future<ProviderReceipt> _watch(String orderId) async {
    final ad = await gateway.load();
    final finished = Completer<bool>();
    var earned = false;
    var failed = false;
    try {
      // Register handlers before showing. Only the reward callback grants coins;
      // dismissing, clicking or merely loading the ad cannot grant them.
      await ad.show(
        onEarned: () {
          if (!finished.isCompleted) earned = true;
        },
        onDismissed: () {
          if (!finished.isCompleted) finished.complete(earned);
        },
        onFailed: () {
          failed = true;
          if (!finished.isCompleted) finished.complete(false);
        },
      );
      if (!await finished.future) {
        throw RewardAdException(
          failed
              ? 'Não foi possível exibir o anúncio. Tente novamente.'
              : 'Anúncio encerrado sem recompensa. Nenhuma moeda adicionada.',
        );
      }
      return _earned[orderId] = ProviderReceipt(
        orderId,
        source,
        Economy.adReward,
        simulated: false,
        testAd: true,
      );
    } on RewardAdException {
      rethrow;
    } catch (_) {
      throw const RewardAdException(
        'Não foi possível exibir o anúncio. Tente novamente.',
      );
    } finally {
      ad.dispose();
    }
  }
}

class GoogleRewardAdGateway implements RewardAdGateway {
  static const androidTestAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  static const loadTimeout = Duration(seconds: 35);
  Future<InitializationStatus>? _initializing;

  @override
  Future<LoadedRewardAd> load() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const RewardAdException(
        'Os anúncios de teste estão disponíveis nesta versão para Android.',
      );
    }
    try {
      await (_initializing ??= MobileAds.instance.initialize()).timeout(
        loadTimeout,
      );
    } catch (_) {
      _initializing = null;
      throw const RewardAdException(
        'Não foi possível iniciar os anúncios. Verifique sua conexão e tente novamente.',
      );
    }

    final loaded = Completer<LoadedRewardAd?>();
    var expired = false;
    try {
      await RewardedAd.load(
        adUnitId: androidTestAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (expired || loaded.isCompleted) {
              unawaited(ad.dispose());
            } else {
              loaded.complete(_GoogleLoadedRewardAd(ad));
            }
          },
          onAdFailedToLoad: (error) {
            debugPrint('AdMob demo load failed: ${error.code}');
            if (!loaded.isCompleted) loaded.complete(null);
          },
        ),
      );
      final ad = await loaded.future.timeout(loadTimeout);
      if (ad != null) return ad;
    } catch (_) {
      expired = true;
    }
    throw const RewardAdException(
      'Anúncio indisponível. Verifique sua conexão e tente novamente.',
    );
  }
}

class _GoogleLoadedRewardAd implements LoadedRewardAd {
  _GoogleLoadedRewardAd(this.ad);
  final RewardedAd ad;

  @override
  Future<void> show({
    required VoidCallback onEarned,
    required VoidCallback onDismissed,
    required VoidCallback onFailed,
  }) {
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (_) => onDismissed(),
      onAdFailedToShowFullScreenContent: (_, error) => onFailed(),
    );
    return ad.show(onUserEarnedReward: (_, reward) => onEarned());
  }

  @override
  void dispose() => unawaited(ad.dispose());
}
