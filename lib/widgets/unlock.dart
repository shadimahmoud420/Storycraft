import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../services/ads.dart';
import '../services/unlocks.dart';

String premiumName(S s, Premium p) => switch (p) {
      Premium.signatures => s.premiumSignatures,
      Premium.surfaces => s.premiumSurfaces,
      Premium.lyricEffects => s.premiumLyrics,
    };

/// Returns true when [p] is open, asking to watch a rewarded ad first if
/// needed. When no ad can be shown, [p] is opened anyway.
Future<bool> ensureUnlocked(BuildContext context, Premium p) async {
  final unlocks = Unlocks.instance;
  if (unlocks.isOpen(p)) return true;
  final s = S.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final watch = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.lock_open_rounded),
      title: Text(premiumName(s, p)),
      content: Text(s.unlockHint),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(s.cancel),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.ondemand_video_rounded),
          label: Text(s.watchAd),
        ),
      ],
    ),
  );
  if (watch != true) return false;
  final result = await Ads.showRewarded();
  if (result == RewardResult.skipped) {
    messenger.showSnackBar(SnackBar(content: Text(s.adNotFinished)));
    return false;
  }
  await unlocks.grant(p);
  messenger.showSnackBar(SnackBar(
      content: Text(result == RewardResult.unavailable
          ? s.unlockedNoAd
          : s.unlocked)));
  return true;
}

/// Small badge on locked extras.
class LockBadge extends StatelessWidget {
  const LockBadge({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xCC000000),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.lock_rounded,
            size: size * 0.6, color: const Color(0xFFFFD166)),
      );
}
