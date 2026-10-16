import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/surfaces.dart';
import '../models/lyrics.dart';
import '../models/story_layer.dart';
import 'ads.dart';

/// Extras opened for a day by watching a rewarded ad. Without ads
/// (Android for now) everything is open.
enum Premium {
  /// The logo-like signature designs.
  signatures,

  /// Some product-studio backdrops.
  surfaces,

  /// The animated lyric effects of the song video.
  lyricEffects,
}

const premiumSignatureStyles = {
  SignatureStyle.emblem,
  SignatureStyle.ribbon,
  SignatureStyle.brush,
  SignatureStyle.lockup,
  SignatureStyle.corners,
  SignatureStyle.arch,
};

const premiumSurfaceIds = {
  'black_marble',
  'walnut_wood',
  'linen',
  'studio_dark',
};

const premiumLyricEffects = {
  LyricEffect.karaoke,
  LyricEffect.wipe,
  LyricEffect.words,
};

bool isPremiumSurface(StudioSurface s) => premiumSurfaceIds.contains(s.id);

class Unlocks extends ValueNotifier<Map<Premium, DateTime>> {
  Unlocks._() : super(const {});

  static final instance = Unlocks._();

  static String _key(Premium p) => 'unlock_${p.name}';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = {
        for (final p in Premium.values)
          if (prefs.getInt(_key(p)) case final ms?)
            p: DateTime.fromMillisecondsSinceEpoch(ms),
      };
    } catch (_) {}
  }

  /// Whether [p] can be used now.
  bool isOpen(Premium p, {DateTime? now}) =>
      !Ads.enabled ||
      (value[p]?.isAfter(now ?? DateTime.now()) ?? false);

  /// Opens [p] for [Ads.markFreeFor].
  Future<void> grant(Premium p, {DateTime? now}) async {
    final until = (now ?? DateTime.now()).add(Ads.markFreeFor);
    value = {...value, p: until};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key(p), until.millisecondsSinceEpoch);
    } catch (_) {}
  }
}
