import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob: one rewarded ad that hides the StoryCraft mark for a day.
/// iOS only for now (the Android app has no ad unit yet). Before any ad,
/// the consent message (EEA/UK) and Apple's tracking prompt are shown.
class Ads {
  Ads._();

  static const _rewardedIos = 'ca-app-pub-2043867091759528/8663616669';

  /// How long one rewarded ad keeps the mark hidden.
  static const markFreeFor = Duration(hours: 24);

  static bool get enabled => !kIsWeb && Platform.isIOS;

  static Future<bool>? _ready;
  static RewardedAd? _rewarded;

  /// Consent, tracking prompt, SDK start, then a rewarded ad is preloaded.
  /// Safe to call more than once.
  static Future<bool> init() => _ready ??= _init();

  static Future<bool> _init() async {
    if (!enabled) return false;
    try {
      await _gatherConsent();
      if (await AppTrackingTransparency.trackingAuthorizationStatus ==
          TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
      if (!await ConsentInformation.instance.canRequestAds()) return false;
      await MobileAds.instance.initialize();
      unawaited(_load());
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _gatherConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((_) {
        if (!done.isCompleted) done.complete();
      }),
      (_) {
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future;
  }

  /// Whether Settings should offer "Privacy options" (EEA/UK users).
  static Future<bool> privacyOptionsRequired() async {
    if (!enabled) return false;
    return await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
  }

  static void showPrivacyOptions() =>
      ConsentForm.showPrivacyOptionsForm((_) {});

  static Future<RewardedAd?> _load() {
    final result = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: _rewardedIos,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded?.dispose();
          _rewarded = ad;
          result.complete(ad);
        },
        onAdFailedToLoad: (_) => result.complete(null),
      ),
    );
    return result.future;
  }

  /// Shows the rewarded ad. True when the reward was earned, or when no ad
  /// can be shown (no fill, offline, no consent): the user is never stuck.
  /// False only when the viewer closed the ad early.
  static Future<bool> showRewarded() async {
    if (!await init()) return true;
    final ad = _rewarded ??
        await _load().timeout(const Duration(seconds: 8), onTimeout: () => null);
    if (ad == null) return true;
    _rewarded = null;
    var earned = false;
    final closed = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        closed.complete(earned);
        unawaited(_load());
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        closed.complete(true);
        unawaited(_load());
      },
    );
    await ad.show(onUserEarnedReward: (_, __) => earned = true);
    return closed.future;
  }
}
