/// Cartoon illustrations bundled in assets/stickers (see
/// tool/make_stickers.py), grouped by occasion for the sticker picker.
class StoryArt {
  StoryArt._();

  static String asset(String name) => 'assets/stickers/$name.svg';

  /// Garlands and bunting are drawn wide and default to full width.
  static bool isWide(String name) =>
      name == 'lantern_garland' || name == 'bunting';

  static const groups = <ArtGroup, List<String>>{
    ArtGroup.ramadan: [
      'crescent', 'lantern', 'lantern_garland', 'cannon', 'fasting_kid',
      'dates', 'kaaba', 'mosque',
    ],
    ArtGroup.eid: ['balloons', 'gift', 'sweets', 'fireworks', 'bunting'],
    ArtGroup.friday: ['mosque', 'dua_hands', 'misbaha', 'kaaba'],
    ArtGroup.morning: ['sun', 'coffee', 'flowers'],
    ArtGroup.celebrate: [
      'popper', 'trophy', 'cake', 'balloons', 'heart', 'sparkles',
    ],
    ArtGroup.graduation: ['graduate', 'grad_cap', 'diploma', 'sparkles'],
  };

  static Set<String> get all => {for (final g in groups.values) ...g};
}

enum ArtGroup { ramadan, eid, friday, morning, celebrate, graduation }
